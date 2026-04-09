import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_food_entry.dart';

class CommunityFoodService {
  static final CommunityFoodService _instance = CommunityFoodService._internal();
  factory CommunityFoodService() => _instance;
  CommunityFoodService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('community_foods');

  /// Save a manually entered food to the community DB.
  /// Skips silently if the same name (case-insensitive) already exists.
  Future<void> contribute(CommunityFoodEntry entry) async {
    try {
      final existing = await _col
          .where('nameSearch', isEqualTo: entry.nameSearch)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return; // already exists — skip
      await _col.doc(entry.id).set(entry.toMap());
    } catch (_) {
      // Fire-and-forget: ignore all errors (offline, permission, etc.)
    }
  }

  /// Search community foods by name prefix (case-insensitive).
  Future<List<CommunityFoodEntry>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final snapshot = await _col
          .orderBy('nameSearch')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(20)
          .get();
      return snapshot.docs.map(CommunityFoodEntry.fromFirestore).toList();
    } catch (_) {
      return [];
    }
  }

  /// Increment useCount when a community food is selected (fire-and-forget).
  void incrementUseCount(String docId) {
    _col.doc(docId).update({
      'useCount': FieldValue.increment(1),
    }).catchError((_) {});
  }
}
