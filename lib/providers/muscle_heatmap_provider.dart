import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exercise_muscle_map.dart';
import '../providers/training_provider.dart';

/// 過去7日間のトレーニングボリュームを筋肉部位ごとに正規化（0.0〜1.0）
final muscleHeatmapProvider =
    Provider<Map<MuscleGroup, double>>((ref) {
  final trainingState = ref.watch(trainingProvider);
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 7));

  final recentLogs = trainingState.logs
      .where((l) => l.date.isAfter(cutoff))
      .toList();

  // 部位ごとの合計ボリューム（セット数ベース、有酸素は時間ベース）
  final volumeMap = <MuscleGroup, double>{};
  for (final group in MuscleGroup.values) {
    volumeMap[group] = 0.0;
  }

  for (final log in recentLogs) {
    final groups = getMuscleGroups(log.exerciseName);
    double contribution;
    if (log.exerciseType.key == 'cardio') {
      // 有酸素：時間（分）をボリュームとして使用
      contribution = log.durationMinutes > 0
          ? log.durationMinutes.toDouble()
          : 30.0; // デフォルト30分
    } else {
      // 筋トレ：セット数 × 重量（kg）
      contribution = log.sets * (log.weight > 0 ? log.weight : 1.0);
    }
    // 複数筋肉に分散させる（主動筋に70%、補助筋に30%）
    for (var i = 0; i < groups.length; i++) {
      final factor = i == 0 ? 1.0 : 0.4;
      volumeMap[groups[i]] = (volumeMap[groups[i]] ?? 0) + contribution * factor;
    }
  }

  // 最大値で正規化
  final maxVolume = volumeMap.values
      .fold<double>(0, (max, v) => v > max ? v : max);

  if (maxVolume == 0) return volumeMap;

  return volumeMap
      .map((k, v) => MapEntry(k, (v / maxVolume).clamp(0.0, 1.0)));
});
