import 'package:sqflite/sqflite.dart';

Future<void> migrateV9(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS scheduler_jobs (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      target_id TEXT NOT NULL,
      run_after INTEGER NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL,
      payload TEXT NOT NULL,
      last_error TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_scheduler_jobs_due ON scheduler_jobs(status, run_after)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_scheduler_jobs_type_target ON scheduler_jobs(type, target_id)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS scheduler_run_log (
      id TEXT PRIMARY KEY,
      job_id TEXT NOT NULL,
      type TEXT NOT NULL,
      target_id TEXT NOT NULL,
      status TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      finished_at INTEGER,
      error TEXT,
      summary TEXT
    )
  ''');
}
