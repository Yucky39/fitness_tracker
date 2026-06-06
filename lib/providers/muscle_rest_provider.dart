import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_muscle_map.dart';
import 'community_exercise_provider.dart';
import 'settings_provider.dart';
import 'training_provider.dart';

/// 部位ごとの休息（回復）状況。
/// 最後にトレーニングした日からの経過日数と、推奨休息日数を比較して
/// 回復の進捗を表す。
class MuscleRestStatus {
  const MuscleRestStatus({
    required this.group,
    required this.lastTrained,
    required this.restPeriodDays,
    required this.daysSince,
  });

  final MuscleGroup group;

  /// この部位を最後にトレーニングした日時。
  final DateTime lastTrained;

  /// 推奨休息日数（ユーザー設定、デフォルト5日）。
  final int restPeriodDays;

  /// 最終トレーニング日からの経過日数（暦日ベース）。
  final int daysSince;

  /// 推奨休息日数まで残り何日か（0〜restPeriodDays）。
  int get remainingDays =>
      (restPeriodDays - daysSince).clamp(0, restPeriodDays).toInt();

  /// 推奨休息日数を満たし、回復済みとみなせるか。
  bool get isRecovered => daysSince >= restPeriodDays;

  /// 回復の進捗（0.0〜1.0）。プログレスバー表示用。
  double get recoveryFraction {
    if (restPeriodDays <= 0) return 1.0;
    return (daysSince / restPeriodDays).clamp(0.0, 1.0);
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 部位ごとの休息状況を、最後にトレーニングした日が新しい順に返す。
/// 有酸素（cardio）は筋肉の回復という概念に馴染まないため除外する。
final muscleRestStatusProvider = Provider<List<MuscleRestStatus>>((ref) {
  final trainingState = ref.watch(trainingProvider);
  final communityMuscles = ref.watch(communityMuscleOverridesProvider);
  final restPeriodDays =
      ref.watch(settingsProvider.select((s) => s.restPeriodDays));

  // 部位ごとの最終トレーニング日時を求める。
  final lastTrained = <MuscleGroup, DateTime>{};
  for (final log in trainingState.logs) {
    final groups = muscleGroupsResolved(log.exerciseName, communityMuscles);
    for (final g in groups) {
      if (g == MuscleGroup.cardio) continue;
      final prev = lastTrained[g];
      if (prev == null || log.date.isAfter(prev)) {
        lastTrained[g] = log.date;
      }
    }
  }

  final today = _dateOnly(DateTime.now());
  final statuses = <MuscleRestStatus>[];
  lastTrained.forEach((group, date) {
    final daysSince = today.difference(_dateOnly(date)).inDays;
    statuses.add(MuscleRestStatus(
      group: group,
      lastTrained: date,
      restPeriodDays: restPeriodDays,
      daysSince: daysSince < 0 ? 0 : daysSince,
    ));
  });

  statuses.sort((a, b) => b.lastTrained.compareTo(a.lastTrained));
  return statuses;
});
