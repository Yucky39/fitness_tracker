/// Abstract interface for database operations.
/// Provides a platform-agnostic API that mirrors sqflite's Database methods.
abstract class DatabaseAdapter {
  Future<void> initialize();

  Future<int> insert(String table, Map<String, dynamic> values);

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  });

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  });

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs});
}
