import '../data/exercise_muscle_map.dart';
import '../models/community_exercise_definition.dart';
import '../models/training_log.dart';

/// 共通種目 DB に一致があればその器具カテゴリを使い、なければテンプレから推定する。
ExerciseType inferExerciseTypeWithCommunity(
  String rawName,
  List<CommunityExerciseDefinition> community,
) {
  final key = normalizeExerciseStorageKey(rawName);
  if (key.isEmpty) return ExercisePresets.inferType(rawName);
  for (final d in community) {
    if (d.normalizedKey == key) return d.exerciseType;
  }
  return ExercisePresets.inferType(rawName);
}
