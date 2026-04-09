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
      version: 17,
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
    if (oldVersion < 10) {
      await db.execute(
          "ALTER TABLE food_items ADD COLUMN detailed_nutrients_json TEXT");
    }
    if (oldVersion < 11) {
      await db.execute(
          "ALTER TABLE training_logs ADD COLUMN rpe INTEGER");
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS training_plans(
          id TEXT PRIMARY KEY,
          name TEXT,
          goal TEXT,
          target_muscles TEXT,
          days_per_week INTEGER,
          intensity TEXT,
          plan_days TEXT,
          overview TEXT,
          created_at TEXT
        )
      ''');
    }
    if (oldVersion < 13) {
      await db.execute(
          "ALTER TABLE training_plans ADD COLUMN cut_style TEXT");
    }
    if (oldVersion < 14) {
      await db.execute(
          "ALTER TABLE training_plans ADD COLUMN equipment TEXT DEFAULT 'fullGym'");
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS water_logs(
          id TEXT PRIMARY KEY,
          amount_ml INTEGER NOT NULL,
          date TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sleep_logs(
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          duration_m INTEGER NOT NULL,
          source TEXT DEFAULT 'health'
        )
      ''');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS achievements(
          id TEXT PRIMARY KEY,
          badge_key TEXT NOT NULL UNIQUE,
          unlocked_at TEXT,
          progress INTEGER DEFAULT 0
        )
      ''');
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
        detailed_nutrients_json TEXT,
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
        rpe INTEGER,
        note TEXT,
        date TEXT,
        ai_advice TEXT
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

    await db.execute('''
      CREATE TABLE training_plans(
        id TEXT PRIMARY KEY,
        name TEXT,
        goal TEXT,
        target_muscles TEXT,
        cut_style TEXT,
        days_per_week INTEGER,
        intensity TEXT,
        equipment TEXT DEFAULT 'fullGym',
        plan_days TEXT,
        overview TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE water_logs(
        id TEXT PRIMARY KEY,
        amount_ml INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sleep_logs(
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        duration_m INTEGER NOT NULL,
        source TEXT DEFAULT 'health'
      )
    ''');

    await db.execute('''
      CREATE TABLE achievements(
        id TEXT PRIMARY KEY,
        badge_key TEXT NOT NULL UNIQUE,
        unlocked_at TEXT,
        progress INTEGER DEFAULT 0
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
