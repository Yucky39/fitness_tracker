import 'database_interface.dart';
import 'database_sqflite.dart';

DatabaseAdapter createDatabaseAdapter() => SqfliteDatabaseAdapter();
