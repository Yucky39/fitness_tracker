import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/daily_coach_provider.dart';
import '../services/daily_coach_service.dart';
import '../theme/bewell_colors.dart';
import 'ai_error_text.dart';

/// ホーム最上部に置く「今日のコーチング」カード。
/// 表示時にデータ同期後、プレミアムユーザーへ先回り自動生成を試みる。
class DailyCoachCard extends ConsumerStatefulWidget {
  const DailyCoachCard({super.key});

  @override
  ConsumerState<DailyCoachCard> createState() => _DailyCoachCardState();
}

class _DailyCoachCardState extends ConsumerState<DailyCoachCard> {
  var _autoTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onVisible());
  }

  Future<void> _onVisible() async {
    if (_autoTriggered) return;
    _autoTriggered = true;
    await ref.read(dailyCoachProvider.notifier).maybeAutoGenerate();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.bewellColors;
    final coach = ref.watch(dailyCoachProvider);
    final notifier = ref.read(dailyCoachProvider.notifier);
    final slot = notifier.currentSlot;
    final message = notifier.messageForSlot(slot);
    final otherSlot = slot == CoachTimeSlot.morning
        ? CoachTimeSlot.evening
        : CoachTimeSlot.morning;
    final otherMessage = notifier.messageForSlot(otherSlot);

    Widget body;
    if (coach.isLoading && coach.loadingSlot == slot) {
      body = Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'あなたの記録を読み取っています…',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    } else if (coach.error != null && message == null) {
      body = AiErrorText(coach.error!);
    } else if (message != null && message.isNotEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 14, height: 1.55)),
          if (otherMessage != null && otherMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                '${otherSlot.label}のコーチングを見る',
                style: TextStyle(fontSize: 12, color: scheme.primary),
              ),
              children: [
                Text(
                  otherMessage,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: coach.isLoading
                  ? null
                  : () => notifier.generate(slot: slot, force: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('更新'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot == CoachTimeSlot.evening
                ? '今日1日を振り返り、明日への一手をお届けします。'
                : '睡眠・トレ・食事・体型をまとめて見て、今日の一手を先回りでお届けします。',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: coach.isLoading
                ? null
                : () => notifier.generate(slot: slot),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text('${slot.label}のコーチングを受け取る'),
          ),
        ],
      );
    }

    return Card(
      elevation: 0,
      color: semantic.aiAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: semantic.aiAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.sports_gymnastics_rounded,
                      color: semantic.aiAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${slot.label}のコーチング',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '手の中のパーソナルトレーナー',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}
