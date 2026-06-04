import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription.dart';

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

  /// アプリ起動時に呼ぶ。購入完了イベントを監視してFirestoreに反映する。
  void initialize() {
    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  void dispose() {
    _purchaseSub?.cancel();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (AiCreditProducts.isCredit(purchase.productID)) {
          await _addCreditOnServer(purchase);
        } else {
          await _activateOnServer(purchase);
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

  Future<void> _activateOnServer(PurchaseDetails purchase) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
          .httpsCallable('activateSubscription');
      await callable.call({
        'productId': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // サーバー側の活性化に失敗してもアプリはクラッシュしない。
      // 次回起動時にリストア機能で再試行できる。
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
