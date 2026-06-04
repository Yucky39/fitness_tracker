import 'package:flutter/material.dart';

import '../services/ai_exceptions.dart';
import 'ai_credit_sheet.dart';

/// AI機能のエラー表示用の共通バナー。
///
/// エラーが当月の利用枠の上限（[AiUsageLimitException]）の場合は、
/// 分かりやすいメッセージと「追加パック」導線（[AiCreditSheet]）を表示する。
/// それ以外のエラーは通常の赤字メッセージとして表示する。
/// [error] が null のときは何も表示しない。
class AiLimitBanner extends StatelessWidget {
  final String? error;

  const AiLimitBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final err = error;
    if (err == null || err.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    if (!AiUsageLimitException.isLimit(err)) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(err, style: TextStyle(color: cs.error, fontSize: 13)),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              err,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => AiCreditSheet.show(context),
            child: const Text('追加パック'),
          ),
        ],
      ),
    );
  }
}
