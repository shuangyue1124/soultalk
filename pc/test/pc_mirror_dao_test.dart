import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk_pc/services/database/pc_database_service.dart';
import 'package:soultalk_pc/services/database/pc_mirror_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late PcMirrorDao dao;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
    dao = PcMirrorDao(dbService: _TestPcDatabaseService(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('upserts and reads mirror rows', () async {
    await dao.upsertRows('messages', [
      {'id': 'm1', 'content': 'hello', 'created_at': '2026-05-24T00:00:00Z'},
    ]);
    await dao.upsertRows('messages', [
      {'id': 'm1', 'content': 'updated', 'created_at': '2026-05-24T00:00:00Z'},
    ]);

    final rows = await dao.getRows('messages');

    expect(rows, hasLength(1));
    expect(rows.single['content'], 'updated');
  });
}

class _TestPcDatabaseService implements PcDatabaseService {
  final Database _database;

  _TestPcDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;
}
