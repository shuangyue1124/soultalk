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

void main() {
  late Directory root;
  late AppPaths paths;
  late Database db;
  late DatabaseService dbService;

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('compat_bootstrap_test_');
    paths = AppPaths.fromRootForTesting(root);
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await migrateV7(db);
    dbService = _TestDatabaseService(db);
    await paths.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('rebuilds file and st compat indexes from authority files', () async {
    await File('${paths.characters.path}/Alice.json').writeAsString(
      jsonEncode({
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {
          'name': 'Alice',
          'tags': ['friend'],
        },
      }),
    );

    final chatDir = Directory('${paths.chats.path}/Alice');
    await chatDir.create(recursive: true);
    await File('${chatDir.path}/Alice - today.jsonl').writeAsString(
      [
        jsonEncode({'user_name': 'User', 'character_name': 'Alice'}),
        jsonEncode({
          'name': 'Alice',
          'is_user': false,
          'send_date': '2026-05-23T10:00:00Z',
          'mes': 'Hi',
        }),
      ].join('\n'),
    );

    await File('${paths.worlds.path}/World.json').writeAsString(
      jsonEncode({
        'entries': {
          '1': {
            'uid': 1,
            'key': ['city'],
            'content': 'Lore',
          },
        },
      }),
    );

    await File(
      '${paths.settings.path}/OpenAI Settings/Default.json',
    ).writeAsString(jsonEncode({'chat_completion_source': 'claude'}));

    final service = CompatStorageBootstrapService(
      paths: paths,
      fileStore: CompatFileStore(paths: paths),
      manifestService: FileManifestService(),
      fileIndexDao: FileIndexDao(dbService),
      characterIndexDao: STCharacterIndexDao(dbService),
      chatIndexDao: STChatIndexDao(dbService),
      worldIndexDao: STWorldIndexDao(dbService),
      presetIndexDao: STPresetIndexDao(dbService),
    );

    await service.initializeAndRebuildIndex();

    expect(await FileIndexDao(dbService).getAllActive(), hasLength(4));
    expect(
      (await STCharacterIndexDao(dbService).getAll()).single.name,
      'Alice',
    );
    expect((await STChatIndexDao(dbService).getAll()).single.messageCount, 1);
    expect((await STWorldIndexDao(dbService).getAll()).single.entryCount, 1);
    expect((await STPresetIndexDao(dbService).getAll()).single.apiId, 'openai');
  });
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
