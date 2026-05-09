import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

/// AI機能が有料の場合に表示するボトムシート。
/// 購入・リストアまでここで完結する。
class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PaywallSheet(),
    );
  }

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  // プロモコード入力
  final _promoController = TextEditingController();
  bool _promoLoading = false;
  String? _promoError;
  String? _promoSuccess;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await SubscriptionService().fetchProducts();
      // 月額を先に表示
      products.sort((a, b) {
        if (a.id == SubscriptionProducts.monthlyId) return -1;
        if (b.id == SubscriptionProducts.monthlyId) return 1;
        return 0;
      });
      if (mounted) setState(() { _products = products; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _purchase(ProductDetails product) async {
    setState(() { _purchasing = true; _error = null; });
    try {
      await SubscriptionService().purchase(product);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _purchasing = false; });
    }
  }

  Future<void> _redeemPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() { _promoLoading = true; _promoError = null; _promoSuccess = null; });
    try {
      final days = await SubscriptionService().redeemPromoCode(code);
      if (!mounted) return;
      setState(() {
        _promoSuccess = 'コードが適用されました！${days}日間のプレミアムが有効になります。';
        _promoLoading = false;
        _promoController.clear();
      });
      // 少し待ってから閉じる
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString()
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceFirst('Exception: ', '')
          .trim();
      setState(() { _promoError = msg; _promoLoading = false; });
    }
  }

  Future<void> _restore() async {
    setState(() { _purchasing = true; _error = null; });
    try {
      await SubscriptionService().restorePurchases();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入履歴を復元しました')),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _error = '復元に失敗しました。もう一度お試しください。'; _purchasing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ヘッダー
            Icon(Icons.auto_awesome_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              'プレミアムプラン',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AIがあなたの食事・トレーニングを\nまるごとサポートします',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            // 機能一覧
            _FeatureRow(icon: Icons.camera_alt_outlined, text: '食事写真からAIが栄養を自動解析'),
            _FeatureRow(icon: Icons.restaurant_menu_outlined, text: '毎日の栄養バランスをAIがアドバイス'),
            _FeatureRow(icon: Icons.fitness_center_outlined, text: 'トレーニング記録をAIが個別評価'),
            _FeatureRow(icon: Icons.calendar_month_outlined, text: 'あなた専用のトレーニングプランをAI生成'),
            const SizedBox(height: 28),
            // 商品ボタン
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_products.isEmpty)
              Center(
                child: Text(
                  'ストア情報を取得できませんでした。\nネットワーク接続を確認してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              )
            else
              ..._products.map((p) => _ProductButton(
                product: p,
                isPrimary: p.id == SubscriptionProducts.monthlyId,
                loading: _purchasing,
                onTap: () => _purchase(p),
              )),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            // プロモコード入力
            Text(
              'プロモコードをお持ちの方',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'コードを入力',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _redeemPromo(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: (_promoLoading || _purchasing)
                      ? null
                      : _redeemPromo,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _promoLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('適用'),
                ),
              ],
            ),
            if (_promoSuccess != null) ...[
              const SizedBox(height: 8),
              Text(_promoSuccess!,
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
            ],
            if (_promoError != null) ...[
              const SizedBox(height: 8),
              Text(_promoError!,
                  style: TextStyle(color: cs.error, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            // リストア・注意書き
            Center(
              child: TextButton(
                onPressed: _purchasing ? null : _restore,
                child: const Text('以前の購入を復元する'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '・サブスクリプションは各ストアアカウントに請求されます\n'
              '・期間終了の24時間前までに解約しない限り自動更新されます\n'
              '・無料トライアル中に解約した場合は課金されません',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _ProductButton extends StatelessWidget {
  final ProductDetails product;
  final bool isPrimary;
  final bool loading;
  final VoidCallback onTap;

  const _ProductButton({
    required this.product,
    required this.isPrimary,
    required this.loading,
    required this.onTap,
  });

  String get _label {
    if (product.id == SubscriptionProducts.annualId) {
      return '年額 ${product.price}  （月あたり約¥2,125 · 15%お得）';
    }
    return '月額 ${product.price}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: isPrimary
          ? FilledButton(
              onPressed: loading ? null : onTap,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_label, style: const TextStyle(fontSize: 15)),
            )
          : OutlinedButton(
              onPressed: loading ? null : onTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: cs.outline),
              ),
              child: Text(_label, style: const TextStyle(fontSize: 15)),
            ),
    );
  }
}
