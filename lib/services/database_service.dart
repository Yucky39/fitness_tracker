import 'database_interface.dart';
import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_mobile.dart'
    if (dart.library.html) 'database_factory_web.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseAdapter? _adapter;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<DatabaseAdapter> get database async {
    if (_adapter != null) return _adapter!;
    _adapter = createDatabaseAdapter();
    await _adapter!.initialize();
    return _adapter!;
  }
}
