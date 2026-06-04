import 'package:flutter/material.dart';

import 'paywall_sheet.dart';

/// AIゲートが弾いたことを示す内部マーカー。
/// プロバイダ層はこの文字列をエラーに載せ、UI層は [AiErrorText] で解釈する。
const String kPaywallErrorMarker = '__paywall__';

bool isPaywallError(String? error) => error == kPaywallErrorMarker;

/// 日次クォータ・短時間連打など、サーバーが返した利用制限メッセージか。
bool isAiQuotaError(String? error) {
  if (error == null || error.isEmpty) return false;
  return error.contains('利用上限') ||
      error.contains('リクエストが速すぎ') ||
      error.contains('画像が大きすぎ');
}

/// AIエラー文字列を解釈して表示する共通ウィジェット。
///
/// `__paywall__` のときは生の文字列を出さず、課金導線（[PaywallSheet]）への
/// ボタン付きの案内を表示する。それ以外は通常のエラーメッセージを表示する。
class AiErrorText extends StatelessWidget {
  const AiErrorText(this.error, {super.key, this.center = false});

  final String error;
  final bool center;

  @override
  Widget build(BuildContext context) {
    if (isPaywallError(error)) {
      return _PaywallNotice(center: center);
    }
    if (isAiQuotaError(error)) {
      return _QuotaNotice(message: error, center: center);
    }
    return Text(
      error,
      textAlign: center ? TextAlign.center : null,
      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
    );
  }
}

class _QuotaNotice extends StatelessWidget {
  const _QuotaNotice({required this.message, this.center = false});

  final String message;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.hourglass_empty, size: 18, color: cs.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            textAlign: center ? TextAlign.center : null,
            style: TextStyle(color: cs.error, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PaywallNotice extends StatelessWidget {
  const _PaywallNotice({this.center = false});

  final bool center;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'この機能はプレミアムプラン（または自前のAIキー）が必要です。',
          textAlign: center ? TextAlign.center : null,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => PaywallSheet.show(context),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('プレミアムを見る'),
        ),
      ],
    );
  }
}
