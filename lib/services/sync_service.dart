import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// Handles bidirectional sync between local SQLite/localStorage and Firestore.
///
/// Strategy:
/// - On register: upload existing local data to Firestore (keep data when creating account)
/// - On login: download Firestore data and merge into local DB (no duplicate IDs)
/// - On write: persist locally then sync to Firestore in background
/// - On delete: remove locally then sync deletion to Firestore
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _tables = ['food_items', 'training_logs', 'body_metrics'];

  String? get _userId => AuthService().userId;

  CollectionReference _collection(String table) => _firestore
      .collection('users')
      .doc(_userId)
      .collection(table);

  /// Upload all local records to Firestore (used after registration).
  Future<void> uploadAllData() async {
    if (_userId == null) return;
    final adapter = await DatabaseService().database;

    for (final table in _tables) {
      final rows = await adapter.query(table);
      if (rows.isEmpty) continue;

      final batch = _firestore.batch();
      for (final row in rows) {
        final docRef = _collection(table).doc(row['id'] as String);
        batch.set(docRef, row);
      }
      await batch.commit();
    }
  }

  /// Download Firestore data and merge into local DB (used after login).
  /// Existing local records are kept; only records absent locally are added.
  Future<void> downloadAndMergeData() async {
    if (_userId == null) return;
    final adapter = await DatabaseService().database;

    for (final table in _tables) {
      final snapshot = await _collection(table).get();
      if (snapshot.docs.isEmpty) continue;

      // Build a set of IDs already in local DB
      final localRows = await adapter.query(table);
      final localIds = localRows.map((r) => r['id'] as String).toSet();

      for (final doc in snapshot.docs) {
        if (!localIds.contains(doc.id)) {
          await adapter.insert(table, doc.data() as Map<String, dynamic>);
        }
      }
    }
  }

  /// Sync a single record to Firestore (fire-and-forget).
  void syncRecord(String table, Map<String, dynamic> data) {
    if (_userId == null) return;
    _collection(table)
        .doc(data['id'] as String)
        .set(data)
        .catchError((_) {}); // Ignore offline errors; retry not needed here
  }

  /// Delete a record from Firestore (fire-and-forget).
  void deleteRecord(String table, String id) {
    if (_userId == null) return;
    _collection(table).doc(id).delete().catchError((_) {});
  }
}
