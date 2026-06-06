import 'package:sqflite/sqflite.dart';

Future<void> migrateV7(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS file_index (
      path TEXT PRIMARY KEY,
      domain TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      mtime INTEGER NOT NULL,
      size INTEGER NOT NULL,
      version_vector TEXT,
      deleted INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_file_index_domain ON file_index(domain)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_file_index_updated_at ON file_index(updated_at)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS st_character_index (
      character_id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      spec TEXT,
      spec_version TEXT,
      avatar_path TEXT,
      tags TEXT,
      creator TEXT,
      character_version TEXT,
      favorite INTEGER NOT NULL DEFAULT 0,
      pinned INTEGER NOT NULL DEFAULT 0,
      unread_count INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_st_character_index_name ON st_character_index(name)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS st_chat_index (
      chat_id TEXT PRIMARY KEY,
      character_id TEXT,
      character_name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      title TEXT,
      message_count INTEGER NOT NULL DEFAULT 0,
      last_message_preview TEXT,
      last_message_at INTEGER,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_st_chat_index_character_id ON st_chat_index(character_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_st_chat_index_last_message_at ON st_chat_index(last_message_at)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS st_world_index (
      world_id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      entry_count INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS st_preset_index (
      preset_id TEXT PRIMARY KEY,
      api_id TEXT NOT NULL,
      name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_st_preset_index_api_id ON st_preset_index(api_id)',
  );
}
