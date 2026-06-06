import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/models/memory_card.dart';
import 'package:soultalk/models/memory_state.dart';
import 'package:soultalk/services/backup/backup_service.dart';
import 'package:soultalk/services/database/database_service.dart';

void main() {
  late Directory root;
  late Database db;
  late DatabaseService dbService;

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('backup_service_test_');
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createMemoryTables(db);
    dbService = _TestDatabaseService(db);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('exports active memory tables with memory section', () async {
    final now = DateTime.utc(2026, 5, 23);
    await db.insert('memory_entries', {
      'id': 'entry-1',
      'contact_id': 'contact-1',
      'category': '基本信息',
      'key': 'name',
      'value': 'Alice',
      'updated_at': now.toIso8601String(),
    });
    await db.insert(
      'memory_states',
      MemoryState(
        id: 'state-1',
        contactId: 'contact-1',
        slotName: 'mood',
        slotValue: 'calm',
        updatedAt: now,
      ).toDbMap(),
    );
    await db.insert(
      'memory_cards',
      MemoryCard(
        id: 'card-1',
        contactId: 'contact-1',
        content: 'Likes tea',
        tags: const ['preference'],
        createdAt: now,
      ).toDbMap(),
    );

    final zipPath =
        await BackupService(
          dbService: dbService,
          createAppPaths: () async => AppPaths.fromRootForTesting(root),
        ).exportToZip(
          sections: {BackupSection.memoryEntries},
          targetDir: root.path,
        );

    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    expect(archive.findFile('memory/memory_entries.json'), isNotNull);
    expect(archive.findFile('memory/memory_states.json'), isNotNull);
    expect(archive.findFile('memory/memory_cards.json'), isNotNull);

    final cardRows =
        jsonDecode(
              utf8.decode(
                archive.findFile('memory/memory_cards.json')!.content
                    as List<int>,
              ),
            )
            as List;
    expect(cardRows.single['id'], 'card-1');
  });
}

Future<void> _createMemoryTables(Database db) async {
  await db.execute('''
    CREATE TABLE memory_entries (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '基本信息',
      key TEXT NOT NULL,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE memory_states (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      slot_name TEXT NOT NULL,
      slot_value TEXT NOT NULL DEFAULT '',
      slot_type TEXT NOT NULL DEFAULT 'text',
      status TEXT NOT NULL DEFAULT 'active',
      confidence REAL NOT NULL DEFAULT 0.5,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE memory_cards (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      content TEXT NOT NULL,
      card_type TEXT NOT NULL DEFAULT 'fact',
      importance REAL NOT NULL DEFAULT 0.5,
      confidence REAL NOT NULL DEFAULT 0.5,
      scope TEXT NOT NULL DEFAULT 'local',
      tags TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      reviewed_at TEXT
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
