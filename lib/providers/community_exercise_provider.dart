import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_muscle_map.dart';
import '../models/community_exercise_definition.dart';
import '../services/community_exercise_service.dart';

/// 共通種目リスト（Firestore をストリーム購読）。
final communityExerciseDefinitionsProvider =
    StreamProvider<List<CommunityExerciseDefinition>>((ref) {
  return CommunityExerciseService().watchDefinitions();
});

/// 筋肉ヒートマップ・部位フィルタ用: 正規化キー → 筋群
final communityMuscleOverridesProvider =
    Provider<Map<String, List<MuscleGroup>>>((ref) {
  final async = ref.watch(communityExerciseDefinitionsProvider);
  return async.when(
    data: (list) => {
      for (final def in list) def.normalizedKey: def.muscleGroups,
    },
    loading: () => const {},
    error: (err, stk) => const {},
  );
});
