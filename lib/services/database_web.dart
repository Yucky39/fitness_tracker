import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'database_interface.dart';
import 'sync_tables.dart';

/// Web implementation using in-memory storage backed by localStorage.
class WebDatabaseAdapter implements DatabaseAdapter {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  static const _storageKey = 'fitness_tracker_db';

  @override
  Future<void> initialize() async {
    // アプリが使う全テーブルを初期化（単一の正規リストから生成）。
    for (final table in SyncTables.all) {
      _tables[table] = [];
    }
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null) return;
    try {
      final Map<String, dynamic> data = json.decode(raw);
      // 初期化済みキーではなく保存済みデータのキーを基準に復元する。
      // 動的に putIfAbsent で追加されたテーブルもリロード後に消えない。
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List) {
          _tables[entry.key] = List<Map<String, dynamic>>.from(
            value.map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
    } catch (_) {
      // Corrupted data, start fresh
    }
  }

  void _saveToStorage() {
    html.window.localStorage[_storageKey] = json.encode(_tables);
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    _tables.putIfAbsent(table, () => []);
    _tables[table]!.add(Map<String, dynamic>.from(values));
    _saveToStorage();
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    _tables.putIfAbsent(table, () => []);
    var results = List<Map<String, dynamic>>.from(
      _tables[table]!.map((e) => Map<String, dynamic>.from(e)),
    );

    // Apply WHERE clause
    if (where != null && whereArgs != null) {
      results = _applyWhere(results, where, whereArgs);
    }

    // Apply ORDER BY
    if (orderBy != null) {
      final desc = orderBy.contains('DESC');
      final field =
          orderBy.replaceAll(' ASC', '').replaceAll(' DESC', '').trim();
      results.sort((a, b) {
        final aVal = a[field]?.toString() ?? '';
        final bVal = b[field]?.toString() ?? '';
        return desc ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
      });
    }

    // Apply LIMIT
    if (limit != null && results.length > limit) {
      results = results.sublist(0, limit);
    }

    return results;
  }

  List<Map<String, dynamic>> _applyWhere(
    List<Map<String, dynamic>> rows,
    String where,
    List<dynamic> whereArgs,
  ) {
    // "a = ? AND b = ?"
    if (where.contains(' AND ')) {
      final parts = where.split(' AND ').map((e) => e.trim()).toList();
      if (parts.length == 2 &&
          parts[0].contains('=') &&
          !parts[0].contains('BETWEEN') &&
          parts[1].contains('=') &&
          !parts[1].contains('BETWEEN') &&
          whereArgs.length >= 2) {
        final f0 = parts[0].split('=').first.trim();
        final f1 = parts[1].split('=').first.trim();
        final v0 = whereArgs[0].toString();
        final v1 = whereArgs[1].toString();
        return rows
            .where(
                (row) => row[f0]?.toString() == v0 && row[f1]?.toString() == v1)
            .toList();
      }
    }

    // Support "field = ?" pattern
    if (where.contains('=') && !where.contains('BETWEEN')) {
      final field = where.split('=').first.trim();
      final value = whereArgs.first;
      return rows
          .where((row) => row[field]?.toString() == value.toString())
          .toList();
    }

    // Support "field BETWEEN ? AND ?" pattern
    if (where.contains('BETWEEN')) {
      final field = where.split('BETWEEN').first.trim();
      final start = whereArgs[0].toString();
      final end = whereArgs[1].toString();
      return rows.where((row) {
        final val = row[field]?.toString() ?? '';
        return val.compareTo(start) >= 0 && val.compareTo(end) <= 0;
      }).toList();
    }

    return rows;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    _tables.putIfAbsent(table, () => []);
    final rows = _tables[table]!;
    int count = 0;
    for (var i = 0; i < rows.length; i++) {
      final match = where == null ||
          _applyWhere([rows[i]], where, whereArgs ?? []).isNotEmpty;
      if (match) {
        rows[i] = {...rows[i], ...Map<String, dynamic>.from(values)};
        count++;
      }
    }
    _saveToStorage();
    return count;
  }

  @override
  Future<int> delete(String table,
      {String? where, List<dynamic>? whereArgs}) async {
    _tables.putIfAbsent(table, () => []);
    if (where == null) {
      final count = _tables[table]!.length;
      _tables[table]!.clear();
      _saveToStorage();
      return count;
    }

    final before = _tables[table]!.length;
    _tables[table]!.removeWhere(
      (row) => _applyWhere([row], where, whereArgs ?? []).isNotEmpty,
    );
    _saveToStorage();
    return before - _tables[table]!.length;
  }
}
