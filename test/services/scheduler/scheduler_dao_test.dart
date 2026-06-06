import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v9.dart';
import 'package:soultalk/services/database/scheduler_job_dao.dart';
import 'package:soultalk/services/database/scheduler_run_log_dao.dart';

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

  test('queries due jobs and claims pending job once', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await jobDao.upsert(
      SchedulerJobRecord(
        id: 'job-1',
        type: 'test',
        targetId: 'target',
        runAfter: now - 1,
        retryCount: 0,
        status: 'pending',
        payload: '{}',
        lastError: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await jobDao.upsert(
      SchedulerJobRecord(
        id: 'job-2',
        type: 'test',
        targetId: 'future',
        runAfter: now + 100000,
        retryCount: 0,
        status: 'pending',
        payload: '{}',
        lastError: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect((await jobDao.dueJobs(now)).map((job) => job.id), ['job-1']);
    expect(await jobDao.claimPending('job-1'), isTrue);
    expect(await jobDao.claimPending('job-1'), isFalse);
    expect((await jobDao.dueJobs(now)), isEmpty);
  });

  test('reschedules jobs and records run logs', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await jobDao.upsert(
      SchedulerJobRecord(
        id: 'job-1',
        type: 'test',
        targetId: 'target',
        runAfter: now,
        retryCount: 0,
        status: 'running',
        payload: '{}',
        lastError: null,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await jobDao.reschedule(
      'job-1',
      runAfter: now + 5000,
      status: 'pending',
      retryCount: 2,
      lastError: 'boom',
    );
    final job = await jobDao.getByTypeTarget('test', 'target');
    expect(job!.status, 'pending');
    expect(job.retryCount, 2);
    expect(job.lastError, 'boom');

    final log = await logDao.insertStart(
      jobId: 'job-1',
      type: 'test',
      targetId: 'target',
    );
    await logDao.finish(log.id, status: 'failed', error: 'boom');
    final logs = await logDao.recent(type: 'test');
    expect(logs, hasLength(1));
    expect(logs.single.status, 'failed');
    expect(logs.single.error, 'boom');
    expect(logs.single.finishedAt, isNotNull);
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
