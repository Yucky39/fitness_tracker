import 'database_interface.dart';
import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_mobile.dart'
    if (dart.library.html) 'database_factory_web.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseAdapter? _adapter;
  static Future<DatabaseAdapter>? _opening;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// All callers await the same in-flight open so no consumer sees an adapter
  /// before [DatabaseAdapter.initialize] has finished.
  Future<DatabaseAdapter> get database async {
    if (_adapter != null) return _adapter!;
    _opening ??= _open();
    return _opening!;
  }

  static Future<DatabaseAdapter> _open() async {
    final adapter = createDatabaseAdapter();
    await adapter.initialize();
    _adapter = adapter;
    return adapter;
  }
}
