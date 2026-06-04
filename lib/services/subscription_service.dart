import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';

/// サーバー側の課金反映結果。UI へバナー/スナックバーで通知するために使う。
enum SubscriptionActivationStatus { success, failed }

class SubscriptionActivationEvent {
  const SubscriptionActivationEvent(this.status, this.message);
  final SubscriptionActivationStatus status;
  final String message;
}

/// [InAppPurchase.queryProductDetails] の結果。
/// リストが空の理由を画面で示すために [notFoundProductIds] 等を保持する。
class SubscriptionProductQueryResult {
  const SubscriptionProductQueryResult({
    required this.products,
    this.storeBillingUnavailable = false,
    this.notFoundProductIds = const [],
    this.queryError,
  });

  final List<ProductDetails> products;
  final bool storeBillingUnavailable;
  final List<String> notFoundProductIds;
  final IAPError? queryError;
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._();
  factory SubscriptionService() => _instance;
  SubscriptionService._();

  final _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // 反映失敗で未送信になった購入を保持する（オンライン復帰/起動時に自動リトライ）。
  static const _pendingKey = 'pending_activations';

  final _activationController =
      StreamController<SubscriptionActivationEvent>.broadcast();

  /// 課金反映の成功/失敗イベント。アプリ最上位で購読してUI通知に使う。
  Stream<SubscriptionActivationEvent> get activationEvents =>
      _activationController.stream;

  /// アプリ起動時に呼ぶ。購入完了イベントを監視してFirestoreに反映する。
  void initialize() {
    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate);

    // ログイン済み（セッション復元含む）になったら未反映の購入を自動再試行する。
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) retryPendingActivations();
    });
  }

  void dispose() {
    _purchaseSub?.cancel();
    _activationController.close();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        _activationController.add(const SubscriptionActivationEvent(
          SubscriptionActivationStatus.failed,
          '購入処理中にエラーが発生しました。料金は請求されていません。',
        ));
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (AiCreditProducts.isCredit(purchase.productID)) {
          await _addCreditOnServer(purchase);
        } else {
          await _activate(
            productId: purchase.productID,
            token: purchase.verificationData.serverVerificationData,
            platform: Platform.isIOS ? 'ios' : 'android',
            isRestore: purchase.status == PurchaseStatus.restored,
          );
        }
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (_) {
          // SK2トランザクションでSK1の内部オブジェクトがnullの場合にスローされる。
          // テスト環境のmissingCertificateが原因。本番では発生しない。
        }
      }
    }
  }

  Future<void> _activate({
    required String productId,
    required String token,
    required String platform,
    bool isRestore = false,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
          .httpsCallable('activateSubscription');
      await callable.call({
        'productId': productId,
        'purchaseToken': token,
        'platform': platform,
      });
      await _removePending(token);
      if (!isRestore) {
        _activationController.add(const SubscriptionActivationEvent(
          SubscriptionActivationStatus.success,
          'プレミアムが有効になりました。',
        ));
      }
      // 他に溜まっている未反映分も流す。
      unawaited(retryPendingActivations());
    } catch (_) {
      // 購入はストア上で成立済み。反映失敗分はキューに退避して後で自動再試行する。
      await _addPending(productId, token, platform);
      if (!isRestore) {
        _activationController.add(const SubscriptionActivationEvent(
          SubscriptionActivationStatus.failed,
          '購入は完了しましたが反映に失敗しました。'
              '電波の良い場所で自動的に再試行します。'
              'しばらくしても有効にならない場合は「以前の購入を復元する」をお試しください。',
        ));
      }
    }
  }

  // ── 未反映購入の再送キュー ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writePending(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(list));
  }

  Future<void> _addPending(
      String productId, String token, String platform) async {
    final list = await _readPending();
    if (list.any((e) => e['token'] == token)) return;
    list.add({'productId': productId, 'token': token, 'platform': platform});
    await _writePending(list);
  }

  Future<void> _removePending(String token) async {
    final list = await _readPending();
    list.removeWhere((e) => e['token'] == token);
    await _writePending(list);
  }

  /// 未反映の購入をサーバーへ再送する。起動時・ログイン時・成功時に呼ばれる。
  Future<void> retryPendingActivations() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final list = await _readPending();
    if (list.isEmpty) return;

    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
        .httpsCallable('activateSubscription');
    for (final p in List<Map<String, dynamic>>.from(list)) {
      try {
        await callable.call({
          'productId': p['productId'],
          'purchaseToken': p['token'],
          'platform': p['platform'],
        });
        await _removePending(p['token'] as String);
        _activationController.add(const SubscriptionActivationEvent(
          SubscriptionActivationStatus.success,
          'プレミアムが有効になりました。',
        ));
      } catch (_) {
        // まだ送れない。次の機会に再試行する。
      }
    }
  }

  Future<void> _addCreditOnServer(PurchaseDetails purchase) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
          .httpsCallable('addAiCredit');
      await callable.call({
        'productId': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // サーバ反映に失敗してもクラッシュさせない。リストアで再試行できる。
    }
  }

  /// 商品情報を取得する（空になった理由は [SubscriptionProductQueryResult] を参照）
  Future<SubscriptionProductQueryResult> queryStoreProducts() async {
    return _queryProducts(SubscriptionProducts.all.toSet());
  }

  /// AI追加クレジット（消費型）の商品情報を取得する
  Future<SubscriptionProductQueryResult> queryCreditProducts() async {
    return _queryProducts(AiCreditProducts.all.toSet());
  }

  Future<SubscriptionProductQueryResult> _queryProducts(
      Set<String> ids) async {
    final available = await _iap.isAvailable();
    if (!available) {
      return const SubscriptionProductQueryResult(
        products: [],
        storeBillingUnavailable: true,
      );
    }

    final response = await _iap.queryProductDetails(ids);
    return SubscriptionProductQueryResult(
      products: response.productDetails,
      notFoundProductIds: response.notFoundIDs,
      queryError: response.error,
    );
  }

  /// サブスクを購入する
  Future<void> purchase(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// AI追加クレジット（消費型）を購入する
  Future<void> purchaseCredit(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  /// 過去の購入をリストアする
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// プロモコードを適用してサブスクを有効化する。
  /// 成功時は有効日数を返す。失敗時は例外をスロー。
  Future<int> redeemPromoCode(String code) async {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
        .httpsCallable('redeemPromoCode');
    final result = await callable.call({'code': code});
    return (result.data['durationDays'] as num).toInt();
  }

  /// Firestoreのサブスク状態を直接確認する（起動時の整合性チェック用）
  Future<bool> checkSubscriptionActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
          .httpsCallable('checkSubscription');
      final result = await callable.call();
      return result.data['active'] == true;
    } catch (_) {
      return false;
    }
  }
}
