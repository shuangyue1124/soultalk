import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PcDatabaseService {
  static final PcDatabaseService _instance = PcDatabaseService._internal();
  factory PcDatabaseService() => _instance;
  PcDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'soultalk_pc_mirror.db');
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pc_mirror_rows (
        table_name TEXT NOT NULL,
        id TEXT NOT NULL,
        json TEXT NOT NULL,
        updated_at INTEGER,
        hash TEXT NOT NULL,
        PRIMARY KEY (table_name, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pc_mirror_rows_table ON pc_mirror_rows(table_name)',
    );
  }
}
