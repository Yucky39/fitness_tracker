import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_supplement_entry.dart';

/// 共有サプリメントDB（`community_supplements`）へのアクセス。
/// [CommunityFoodService] と同じく fire-and-forget で貢献する。
class CommunitySupplementService {
  static final CommunitySupplementService _instance =
      CommunitySupplementService._internal();
  factory CommunitySupplementService() => _instance;
  CommunitySupplementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('community_supplements');

  /// 手入力したサプリメントを共有DBへ登録する。
  /// 同名（大文字小文字を無視）が既にあればスキップする。
  Future<void> contribute(CommunitySupplementEntry entry) async {
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

  /// 名称の前方一致（大文字小文字を無視）で共有サプリメントを検索する。
  Future<List<CommunitySupplementEntry>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final snapshot = await _col
          .orderBy('nameSearch')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(20)
          .get();
      return snapshot.docs
          .map(CommunitySupplementEntry.fromFirestore)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 選択時に useCount を加算（fire-and-forget）。
  void incrementUseCount(String docId) {
    _col.doc(docId).update({
      'useCount': FieldValue.increment(1),
    }).catchError((_) {});
  }
}
