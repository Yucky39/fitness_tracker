import 'package:flutter/material.dart';

import '../../models/training_log.dart';

/// 推定1RM（エプリー式）トップ種目のチップ一覧
class TrainingOneRmCard extends StatelessWidget {
  final List<TrainingLog> logs;
  final void Function(String exerciseName) onTapExercise;

  const TrainingOneRmCard({
    super.key,
    required this.logs,
    required this.onTapExercise,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> bestOneRm = {};
    for (final log in logs) {
      if (log.reps > 0 && log.weight > 0) {
        final est = log.weight * (1 + log.reps / 30);
        if (!bestOneRm.containsKey(log.exerciseName) ||
            est > bestOneRm[log.exerciseName]!) {
          bestOneRm[log.exerciseName] = est;
        }
      }
    }
    if (bestOneRm.isEmpty) return const SizedBox.shrink();

    final sorted = bestOneRm.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                SizedBox(width: 6),
                Text(
                  '推定1RM（エプリー式）',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: top.map((e) {
                return GestureDetector(
                  onTap: () => onTapExercise(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${e.value.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            const Text(
              'タップで重量推移グラフを表示',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
