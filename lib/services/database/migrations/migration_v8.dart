import 'package:sqflite/sqflite.dart';

Future<void> migrateV8(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS attachment_index (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      message_id TEXT,
      original_name TEXT NOT NULL,
      mime_type TEXT,
      relative_path TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      size INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_attachment_index_chat ON attachment_index(chat_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_attachment_index_sha ON attachment_index(sha256)',
  );
}
