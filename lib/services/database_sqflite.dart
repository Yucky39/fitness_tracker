import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'database_interface.dart';

class SqfliteDatabaseAdapter implements DatabaseAdapter {
  Database? _database;

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'fitness_tracker.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE food_items(
        id TEXT PRIMARY KEY,
        name TEXT,
        calories INTEGER,
        protein REAL,
        fat REAL,
        carbs REAL,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE training_logs(
        id TEXT PRIMARY KEY,
        exerciseName TEXT,
        weight REAL,
        reps INTEGER,
        sets INTEGER,
        interval INTEGER,
        note TEXT,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE body_metrics(
        id TEXT PRIMARY KEY,
        weight REAL,
        waist REAL,
        bodyFatPercentage REAL,
        imagePath TEXT,
        date TEXT
      )
    ''');
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    return await _database!.insert(table, values);
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    return await _database!.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    return await _database!.delete(table, where: where, whereArgs: whereArgs);
  }
}
