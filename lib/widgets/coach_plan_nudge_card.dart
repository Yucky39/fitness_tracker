import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coach_plan_nudge_provider.dart';
import '../screens/training_plan_screen.dart';

/// 週次のプラン調整をトレーナーから提案するバナー。
class CoachPlanNudgeCard extends ConsumerWidget {
  const CoachPlanNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nudge = ref.watch(coachPlanNudgeProvider);
    if (nudge == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: scheme.tertiary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'トレーナーからの提案',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              nudge.reason,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '対象: ${nudge.plan.name}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TrainingPlanScreen(),
                    ),
                  );
                },
                child: const Text('プランを調整する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
