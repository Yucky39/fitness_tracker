import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/exercise_muscle_map.dart';
import 'training_log.dart';

/// アプリ標準リスト外の種目を、ユーザーが登録した「みんなの種目」（Firestore 共通コレクション）のエントリ。
class CommunityExerciseDefinition {
  /// Firestore のドキュメント ID（normalize 済みキー由来）
  final String id;

  /// 表示名（入力されたままの表記ゆれ許容）
  final String displayName;

  /// 比較用キー [normalizeExerciseStorageKey] と同等
  final String normalizedKey;
  final ExerciseType exerciseType;
  final List<MuscleGroup> muscleGroups;

  const CommunityExerciseDefinition({
    required this.id,
    required this.displayName,
    required this.normalizedKey,
    required this.exerciseType,
    required this.muscleGroups,
  });

  factory CommunityExerciseDefinition.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final muscleKeys = (data['muscle_group_keys'] as List<dynamic>? ?? [])
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final muscles = <MuscleGroup>[];
    for (final k in muscleKeys) {
      MuscleGroup? g;
      for (final cand in MuscleGroup.values) {
        if (cand.name == k) {
          g = cand;
          break;
        }
      }
      if (g != null) muscles.add(g);
    }
    final nk = data['normalized_key'] as String? ?? doc.id;
    return CommunityExerciseDefinition(
      id: doc.id,
      displayName: data['display_name'] as String? ?? doc.id,
      normalizedKey: nk,
      exerciseType: ExerciseType.fromKey(data['exercise_type'] as String?),
      muscleGroups: muscles.isEmpty ? const [MuscleGroup.chest] : muscles,
    );
  }
}
