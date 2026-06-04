import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/ai_usage.dart';
import '../models/subscription.dart';
import '../providers/ai_usage_provider.dart';
import '../services/subscription_service.dart';

/// 当月のAI利用枠が上限に達したときに表示する、追加パック（消費型IAP）購入シート。
class AiCreditSheet extends ConsumerStatefulWidget {
  const AiCreditSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AiCreditSheet(),
    );
  }

  @override
  ConsumerState<AiCreditSheet> createState() => _AiCreditSheetState();
}

class _AiCreditSheetState extends ConsumerState<AiCreditSheet> {
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final result = await SubscriptionService().queryCreditProducts();
      final products = List<ProductDetails>.from(result.products)
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
        _emptyMessage = products.isEmpty
            ? 'ストアに追加パックの商品が見つかりませんでした。時間をおいて再度お試しください。'
            : null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _purchase(ProductDetails product) async {
    setState(() {
      _purchasing = true;
      _error = null;
    });
    try {
      await SubscriptionService().purchaseCredit(product);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _purchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final usage = ref.watch(aiUsageProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Icon(Icons.bolt_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              'AI追加パック',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '今月のAI利用枠の上限に達しました。\n追加パックを購入すると、引き続きAIをご利用いただけます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 20),
            _UsageMeter(usage: usage),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_products.isEmpty)
              Center(
                child: Text(
                  _emptyMessage ?? 'ストア情報を取得できませんでした。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              )
            else
              ..._products.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilledButton.tonal(
                      onPressed: _purchasing ? null : () => _purchase(p),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('${p.title.isNotEmpty ? p.title : p.description} ${p.price}',
                          style: const TextStyle(fontSize: 15)),
                    ),
                  )),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),
            Text(
              '・購入分は当月の利用枠に加算されます\n・消費型のため自動更新はされません',
              style: TextStyle(
                  fontSize: 11, color: cs.onSurfaceVariant, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  final AiUsage usage;
  const _UsageMeter({required this.usage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = usage.usedRatio.clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('今月のAI利用',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            color: ratio >= 1.0 ? cs.error : cs.primary,
          ),
        ),
      ],
    );
  }
}
