import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'fitness_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Food Items Table
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

    // Training Logs Table
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

    // Body Metrics Table
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
}
