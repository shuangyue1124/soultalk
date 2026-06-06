import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_service.dart';

class SchedulerRunLogRecord {
  final String id;
  final String jobId;
  final String type;
  final String targetId;
  final String status;
  final int startedAt;
  final int? finishedAt;
  final String? error;
  final String? summary;

  const SchedulerRunLogRecord({
    required this.id,
    required this.jobId,
    required this.type,
    required this.targetId,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.error,
    required this.summary,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'job_id': jobId,
    'type': type,
    'target_id': targetId,
    'status': status,
    'started_at': startedAt,
    'finished_at': finishedAt,
    'error': error,
    'summary': summary,
  };

  factory SchedulerRunLogRecord.fromMap(Map<String, Object?> map) {
    return SchedulerRunLogRecord(
      id: map['id']! as String,
      jobId: map['job_id']! as String,
      type: map['type']! as String,
      targetId: map['target_id']! as String,
      status: map['status']! as String,
      startedAt: map['started_at']! as int,
      finishedAt: map['finished_at'] as int?,
      error: map['error'] as String?,
      summary: map['summary'] as String?,
    );
  }
}

class SchedulerRunLogDao {
  final DatabaseService _db;
  final Uuid uuid;

  SchedulerRunLogDao(this._db, {Uuid? uuid}) : uuid = uuid ?? const Uuid();

  Future<Database> get _database => _db.database;

  Future<SchedulerRunLogRecord> insertStart({
    required String jobId,
    required String type,
    required String targetId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = SchedulerRunLogRecord(
      id: uuid.v4(),
      jobId: jobId,
      type: type,
      targetId: targetId,
      status: 'running',
      startedAt: now,
      finishedAt: null,
      error: null,
      summary: null,
    );
    final db = await _database;
    await db.insert('scheduler_run_log', record.toMap());
    return record;
  }

  Future<void> finish(
    String id, {
    required String status,
    String? error,
    String? summary,
  }) async {
    final db = await _database;
    await db.update(
      'scheduler_run_log',
      {
        'status': status,
        'finished_at': DateTime.now().millisecondsSinceEpoch,
        'error': error,
        'summary': summary,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SchedulerRunLogRecord>> recent({
    String? type,
    int limit = 50,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'scheduler_run_log',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(SchedulerRunLogRecord.fromMap).toList();
  }
}
