import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/core/file_store/compat_file_store.dart';
import 'package:soultalk/core/file_store/file_manifest_service.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/file_index_dao.dart';
import 'package:soultalk/services/database/migrations/migration_v7.dart';
import 'package:soultalk/services/database/st_character_index_dao.dart';
import 'package:soultalk/services/database/st_chat_index_dao.dart';
import 'package:soultalk/services/database/st_preset_index_dao.dart';
import 'package:soultalk/services/database/st_world_index_dao.dart';
import 'package:soultalk/services/st_compat/compat_storage_bootstrap_service.dart';
import 'package:soultalk/services/st_compat/legacy/legacy_compat_export_service.dart';

void main() {
  late Directory root;
  late AppPaths paths;
  late Database db;
  late DatabaseService dbService;

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('legacy_export_test_');
    paths = AppPaths.fromRootForTesting(root);
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createLegacyTables(db);
    await migrateV7(db);
    dbService = _TestDatabaseService(db);
    await paths.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'exports contacts and messages to st compat files then rebuilds indexes',
    () async {
      await db.insert('contacts', {
        'id': 'c1',
        'name': 'Alice',
        'avatar': null,
        'description': 'A friend',
        'api_config_id': 'api1',
        'system_prompt': 'Stay warm',
        'character_card_json': null,
        'tags': jsonEncode(['friend']),
        'pinned': 0,
        'unread_count': 0,
        'proactive_enabled': 1,
      });
      await db.insert('messages', {
        'id': 'm1',
        'contact_id': 'c1',
        'role': 'user',
        'content': 'Hello',
        'type': 'text',
        'is_streaming': 0,
        'token_count': 1,
        'metadata': '{"foo":"bar"}',
        'created_at': '2026-05-23T10:00:00Z',
      });

      final bootstrap = _bootstrap(paths, dbService);
      final result = await LegacyCompatExportService(
        paths: paths,
        databaseService: dbService,
        bootstrapService: bootstrap,
      ).exportAndRebuildIndex();

      expect(result.characters, 1);
      expect(result.chats, 1);
      expect(
        await File('${paths.characters.path}/Alice.json').exists(),
        isTrue,
      );

      final chatDir = Directory('${paths.chats.path}/Alice');
      final chatFiles = await chatDir
          .list()
          .where((entity) => entity is File)
          .toList();
      expect(chatFiles, hasLength(1));

      final characters = await STCharacterIndexDao(dbService).getAll();
      final chats = await STChatIndexDao(dbService).getAll();
      expect(characters.single.name, 'Alice');
      expect(chats.single.messageCount, 1);
      expect(await FileIndexDao(dbService).getAllActive(), hasLength(2));
    },
  );
}

CompatStorageBootstrapService _bootstrap(
  AppPaths paths,
  DatabaseService dbService,
) {
  return CompatStorageBootstrapService(
    paths: paths,
    fileStore: CompatFileStore(paths: paths),
    manifestService: FileManifestService(),
    fileIndexDao: FileIndexDao(dbService),
    characterIndexDao: STCharacterIndexDao(dbService),
    chatIndexDao: STChatIndexDao(dbService),
    worldIndexDao: STWorldIndexDao(dbService),
    presetIndexDao: STPresetIndexDao(dbService),
  );
}

Future<void> _createLegacyTables(Database db) async {
  await db.execute('''
    CREATE TABLE contacts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      avatar TEXT,
      description TEXT NOT NULL DEFAULT '',
      api_config_id TEXT,
      system_prompt TEXT NOT NULL DEFAULT '',
      character_card_json TEXT,
      tags TEXT NOT NULL DEFAULT '[]',
      pinned INTEGER NOT NULL DEFAULT 0,
      unread_count INTEGER NOT NULL DEFAULT 0,
      proactive_enabled INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE messages (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'text',
      is_streaming INTEGER NOT NULL DEFAULT 0,
      token_count INTEGER NOT NULL DEFAULT 0,
      metadata TEXT,
      created_at TEXT
    )
  ''');
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
