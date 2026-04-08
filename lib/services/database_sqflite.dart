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
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE food_items ADD COLUMN sugar REAL DEFAULT 0");
      await db.execute("ALTER TABLE food_items ADD COLUMN fiber REAL DEFAULT 0");
      await db.execute("ALTER TABLE food_items ADD COLUMN sodium REAL DEFAULT 0");
      await db.execute("ALTER TABLE food_items ADD COLUMN meal_type TEXT DEFAULT 'snack'");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meal_presets(
          id TEXT PRIMARY KEY,
          name TEXT,
          items TEXT,
          created_at TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE training_logs ADD COLUMN exercise_type TEXT DEFAULT 'free_weight'");
    }
    if (oldVersion < 5) {
      await db.execute(
          "ALTER TABLE training_logs ADD COLUMN distance_km REAL DEFAULT 0");
      await db.execute(
          "ALTER TABLE training_logs ADD COLUMN duration_minutes INTEGER DEFAULT 0");
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS training_routines(
          id TEXT PRIMARY KEY,
          name TEXT,
          weekdays TEXT,
          note TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute(
          "ALTER TABLE training_logs ADD COLUMN ai_advice TEXT");
    }
    if (oldVersion < 8) {
      await db.execute(
          "ALTER TABLE meal_presets ADD COLUMN kind TEXT DEFAULT 'meal'");
      await db.execute(
          "ALTER TABLE meal_presets ADD COLUMN recipe_data TEXT");
    }
    if (oldVersion < 9) {
      await db.execute(
          "ALTER TABLE food_items ADD COLUMN micronutrients_json TEXT");
    }
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
        sugar REAL DEFAULT 0,
        fiber REAL DEFAULT 0,
        sodium REAL DEFAULT 0,
        micronutrients_json TEXT,
        meal_type TEXT DEFAULT 'snack',
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE training_logs(
        id TEXT PRIMARY KEY,
        exerciseName TEXT,
        exercise_type TEXT DEFAULT 'free_weight',
        weight REAL,
        reps INTEGER,
        sets INTEGER,
        interval INTEGER,
        distance_km REAL DEFAULT 0,
        duration_minutes INTEGER DEFAULT 0,
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

    await db.execute('''
      CREATE TABLE meal_presets(
        id TEXT PRIMARY KEY,
        name TEXT,
        items TEXT,
        kind TEXT DEFAULT 'meal',
        recipe_data TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE training_routines(
        id TEXT PRIMARY KEY,
        name TEXT,
        weekdays TEXT,
        note TEXT
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
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    return await _database!.update(table, values, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    return await _database!.delete(table, where: where, whereArgs: whereArgs);
  }
}
