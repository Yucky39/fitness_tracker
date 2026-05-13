import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/exercise_muscle_map.dart';
import '../models/community_exercise_definition.dart';
import '../models/training_log.dart';
import 'auth_service.dart';

/// 全ユーザー共通の種目マスター（Firestore ルート `community_exercises`）。
///
/// デプロイする Firestore ルールの例（コンソールまたは firebase deploy）:
///
/// ```
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     match /community_exercises/{id} {
///       allow read: if true;
///       allow create, update: if request.auth != null;
///       allow delete: if false;
///     }
///   }
/// }
/// ```
///
/// （本番では create/update にバリデータやレート制限を足すことを推奨します。）
class CommunityExerciseService {
  static final CommunityExerciseService _instance =
      CommunityExerciseService._internal();
  factory CommunityExerciseService() => _instance;
  CommunityExerciseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String collectionName = 'community_exercises';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collectionName);

  /// アプリ側の名前正規化（空白除去・lower）に合わせたドキュメント ID。
  String firestoreDocIdForDisplayName(String displayName) =>
      normalizeExerciseStorageKey(displayName).replaceAll('/', '_');

  Stream<List<CommunityExerciseDefinition>> watchDefinitions() =>
      _col.snapshots().map(
            (snap) =>
                snap.docs.map(CommunityExerciseDefinition.fromDoc).toList(),
          );

  Future<void> contribute({
    required String displayName,
    required ExerciseType exerciseType,
    required List<MuscleGroup> muscleGroups,
  }) async {
    final uid = AuthService().userId;
    if (uid == null) throw StateError('ログインが必要です');

    final trimmed = displayName.trim();
    if (trimmed.isEmpty) throw ArgumentError('種目名を入力してください');

    final key = normalizeExerciseStorageKey(trimmed);
    if (key.isEmpty) throw ArgumentError('種目名が短すぎます');

    if (muscleGroups.isEmpty) {
      throw ArgumentError('主な鍛える部位を1つ以上選んでください');
    }

    final docId = firestoreDocIdForDisplayName(trimmed);
    final keys = muscleGroups.map((m) => m.name).toList();

    await _col.doc(docId).set({
      'display_name': trimmed,
      'normalized_key': key,
      'exercise_type': exerciseType.key,
      'muscle_group_keys': FieldValue.arrayUnion(keys),
      'updated_at': FieldValue.serverTimestamp(),
      'contributor_uid_last': uid,
    }, SetOptions(merge: true));
  }
}
