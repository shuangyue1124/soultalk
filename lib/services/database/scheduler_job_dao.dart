import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class SchedulerJobRecord {
  final String id;
  final String type;
  final String targetId;
  final int runAfter;
  final int retryCount;
  final String status;
  final String payload;
  final String? lastError;
  final int createdAt;
  final int updatedAt;

  const SchedulerJobRecord({
    required this.id,
    required this.type,
    required this.targetId,
    required this.runAfter,
    required this.retryCount,
    required this.status,
    required this.payload,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type,
    'target_id': targetId,
    'run_after': runAfter,
    'retry_count': retryCount,
    'status': status,
    'payload': payload,
    'last_error': lastError,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory SchedulerJobRecord.fromMap(Map<String, Object?> map) {
    return SchedulerJobRecord(
      id: map['id']! as String,
      type: map['type']! as String,
      targetId: map['target_id']! as String,
      runAfter: map['run_after']! as int,
      retryCount: map['retry_count']! as int,
      status: map['status']! as String,
      payload: map['payload']! as String,
      lastError: map['last_error'] as String?,
      createdAt: map['created_at']! as int,
      updatedAt: map['updated_at']! as int,
    );
  }
}

class SchedulerJobDao {
  final DatabaseService _db;

  SchedulerJobDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> upsert(SchedulerJobRecord record) async {
    final db = await _database;
    await db.insert(
      'scheduler_jobs',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SchedulerJobRecord>> dueJobs(int nowMillis) async {
    final db = await _database;
    final rows = await db.query(
      'scheduler_jobs',
      where: 'status = ? AND run_after <= ?',
      whereArgs: ['pending', nowMillis],
      orderBy: 'run_after ASC',
    );
    return rows.map(SchedulerJobRecord.fromMap).toList();
  }

  Future<void> updateStatus(
    String id,
    String status, {
    String? lastError,
  }) async {
    final db = await _database;
    await db.update(
      'scheduler_jobs',
      {
        'status': status,
        'last_error': lastError,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<SchedulerJobRecord?> getByTypeTarget(
    String type,
    String targetId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'scheduler_jobs',
      where: 'type = ? AND target_id = ?',
      whereArgs: [type, targetId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SchedulerJobRecord.fromMap(rows.first);
  }

  Future<bool> claimPending(String id) async {
    final db = await _database;
    final updated = await db.update(
      'scheduler_jobs',
      {
        'status': 'running',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'pending'],
    );
    return updated == 1;
  }

  Future<void> reschedule(
    String id, {
    required int runAfter,
    required String status,
    int? retryCount,
    String? lastError,
  }) async {
    final db = await _database;
    final values = <String, Object?>{
      'run_after': runAfter,
      'status': status,
      'last_error': lastError,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (retryCount != null) values['retry_count'] = retryCount;
    await db.update('scheduler_jobs', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markCompleted(String id) async {
    await updateStatus(id, 'completed');
  }

  Future<void> markFailed(String id, String error) async {
    await updateStatus(id, 'failed', lastError: error);
  }

  Future<void> disable(String id) async {
    await updateStatus(id, 'disabled');
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('scheduler_jobs', where: 'id = ?', whereArgs: [id]);
  }
}
