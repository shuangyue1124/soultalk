import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v9.dart';
import 'package:soultalk/services/database/scheduler_job_dao.dart';
import 'package:soultalk/services/database/scheduler_run_log_dao.dart';
import 'package:soultalk/services/scheduler/scheduler_task_handler.dart';
import 'package:soultalk/services/scheduler/unified_scheduler.dart';

void main() {
  late Database db;
  late DatabaseService dbService;
  late SchedulerJobDao jobDao;
  late SchedulerRunLogDao logDao;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await migrateV9(db);
    dbService = _TestDatabaseService(db);
    jobDao = SchedulerJobDao(dbService);
    logDao = SchedulerRunLogDao(dbService);
  });

  tearDown(() async {
    await db.close();
  });

  test('runs due job and reschedules successful recurring task', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _insertJob(jobDao, runAfter: now - 1);
    final scheduler = UnifiedScheduler(jobDao: jobDao, runLogDao: logDao);

    scheduler.startWithoutTimerForTesting(
      handlers: [_SuccessHandler(now + 1000)],
    );
    await scheduler.tick();

    final job = await jobDao.getByTypeTarget('test', 'target');
    expect(job!.status, 'pending');
    expect(job.retryCount, 0);
    expect(job.runAfter, now + 1000);
    final logs = await logDao.recent(type: 'test');
    expect(logs.single.status, 'completed');
    expect(logs.single.summary, 'ok');
  });

  test('records failure and retry schedule', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _insertJob(jobDao, runAfter: now - 1);
    final scheduler = UnifiedScheduler(jobDao: jobDao, runLogDao: logDao);

    scheduler.startWithoutTimerForTesting(handlers: [_FailureHandler()]);
    await scheduler.tick();

    final job = await jobDao.getByTypeTarget('test', 'target');
    expect(job!.status, 'pending');
    expect(job.retryCount, 1);
    expect(job.lastError, 'boom');
    expect(job.runAfter, greaterThan(now));
    final logs = await logDao.recent(type: 'test');
    expect(logs.single.status, 'failed');
    expect(logs.single.error, 'boom');
  });

  test('unknown handler marks job failed', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _insertJob(jobDao, runAfter: now - 1);
    final scheduler = UnifiedScheduler(jobDao: jobDao, runLogDao: logDao);

    scheduler.startWithoutTimerForTesting(handlers: []);
    await scheduler.tick();

    final job = await jobDao.getByTypeTarget('test', 'target');
    expect(job!.status, 'failed');
    final logs = await logDao.recent(type: 'test');
    expect(logs.single.status, 'failed');
    expect(logs.single.error, contains('No scheduler handler'));
  });
}

Future<void> _insertJob(SchedulerJobDao dao, {required int runAfter}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return dao.upsert(
    SchedulerJobRecord(
      id: 'job-1',
      type: 'test',
      targetId: 'target',
      runAfter: runAfter,
      retryCount: 0,
      status: 'pending',
      payload: '{}',
      lastError: null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

class _SuccessHandler implements SchedulerTaskHandler {
  final int nextRunAfter;
  _SuccessHandler(this.nextRunAfter);

  @override
  String get type => 'test';

  @override
  Future<SchedulerTaskResult> run(SchedulerJobRecord job) async {
    return SchedulerTaskResult.success(
      summary: 'ok',
      nextRunAfterMillis: nextRunAfter,
    );
  }
}

class _FailureHandler implements SchedulerTaskHandler {
  @override
  String get type => 'test';

  @override
  Future<SchedulerTaskResult> run(SchedulerJobRecord job) async {
    return const SchedulerTaskResult.failure(error: 'boom');
  }
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
