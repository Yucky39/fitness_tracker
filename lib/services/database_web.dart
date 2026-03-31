import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'database_interface.dart';

/// Web implementation using in-memory storage backed by localStorage.
class WebDatabaseAdapter implements DatabaseAdapter {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  static const _storageKey = 'fitness_tracker_db';

  @override
  Future<void> initialize() async {
    _tables['food_items'] = [];
    _tables['training_logs'] = [];
    _tables['body_metrics'] = [];
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null) return;
    try {
      final Map<String, dynamic> data = json.decode(raw);
      for (final table in _tables.keys) {
        if (data[table] != null) {
          _tables[table] = List<Map<String, dynamic>>.from(
            (data[table] as List).map((e) => Map<String, dynamic>.from(e)),
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
      final field = orderBy.replaceAll(' ASC', '').replaceAll(' DESC', '').trim();
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
    // Support "field = ?" pattern
    if (where.contains('=') && !where.contains('BETWEEN')) {
      final field = where.split('=').first.trim();
      final value = whereArgs.first;
      return rows.where((row) => row[field]?.toString() == value.toString()).toList();
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
    final rows = _tables[table]!;
    final targets = where != null
        ? _applyWhere(List.from(rows), where, whereArgs ?? [])
        : List<Map<String, dynamic>>.from(rows);
    final targetIds = targets.map((r) => r['id']).toSet();
    int count = 0;
    for (var i = 0; i < rows.length; i++) {
      if (targetIds.contains(rows[i]['id'])) {
        rows[i] = Map<String, dynamic>.from(values);
        count++;
      }
    }
    _saveToStorage();
    return count;
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    if (where == null) {
      final count = _tables[table]!.length;
      _tables[table]!.clear();
      _saveToStorage();
      return count;
    }

    final before = _tables[table]!.length;
    final keep = List<Map<String, dynamic>>.from(_tables[table]!);
    final toRemove = _applyWhere(keep, where, whereArgs ?? []);
    for (final item in toRemove) {
      _tables[table]!.remove(item);
    }
    _saveToStorage();
    return before - _tables[table]!.length;
  }
}
