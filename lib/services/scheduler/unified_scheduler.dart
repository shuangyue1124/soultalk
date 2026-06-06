import 'dart:async';

import '../database/database_service.dart';
import '../database/scheduler_job_dao.dart';
import '../database/scheduler_run_log_dao.dart';
import 'scheduler_policy.dart';
import 'scheduler_task_handler.dart';

class UnifiedScheduler {
  final SchedulerJobDao _jobDao;
  final SchedulerRunLogDao _runLogDao;

  UnifiedScheduler({SchedulerJobDao? jobDao, SchedulerRunLogDao? runLogDao})
    : _jobDao = jobDao ?? SchedulerJobDao(DatabaseService()),
      _runLogDao = runLogDao ?? SchedulerRunLogDao(DatabaseService());

  static final UnifiedScheduler instance = UnifiedScheduler();

  Timer? _timer;
  bool _isTicking = false;
  SchedulerPolicy _policy = const SchedulerPolicy();
  Map<String, SchedulerTaskHandler> _handlers = const {};

  void start({
    required List<SchedulerTaskHandler> handlers,
    SchedulerPolicy policy = const SchedulerPolicy(),
  }) {
    _timer?.cancel();
    _configure(handlers: handlers, policy: policy);
    _timer = Timer.periodic(_policy.tickInterval, (_) => unawaited(tick()));
    unawaited(tick());
  }

  void startWithoutTimerForTesting({
    required List<SchedulerTaskHandler> handlers,
    SchedulerPolicy policy = const SchedulerPolicy(),
  }) {
    _timer?.cancel();
    _timer = null;
    _configure(handlers: handlers, policy: policy);
  }

  void _configure({
    required List<SchedulerTaskHandler> handlers,
    required SchedulerPolicy policy,
  }) {
    _policy = policy;
    _handlers = {for (final handler in handlers) handler.type: handler};
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> tick() async {
    if (_isTicking) return;
    _isTicking = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final dueJobs = await _jobDao.dueJobs(now);
      for (final job in dueJobs.take(_policy.maxDueJobsPerTick)) {
        final claimed = await _jobDao.claimPending(job.id);
        if (!claimed) continue;
        await _runJob(job);
      }
    } finally {
      _isTicking = false;
    }
  }

  Future<void> _runJob(SchedulerJobRecord job) async {
    final log = await _runLogDao.insertStart(
      jobId: job.id,
      type: job.type,
      targetId: job.targetId,
    );
    final handler = _handlers[job.type];
    if (handler == null) {
      const error = 'No scheduler handler registered';
      await _runLogDao.finish(log.id, status: 'failed', error: error);
      await _jobDao.markFailed(job.id, error);
      return;
    }

    try {
      final result = await handler.run(job);
      if (result.success) {
        await _runLogDao.finish(
          log.id,
          status: 'completed',
          summary: result.summary,
        );
        if (result.nextRunAfterMillis != null) {
          await _jobDao.reschedule(
            job.id,
            runAfter: result.nextRunAfterMillis!,
            status: 'pending',
            retryCount: 0,
          );
        } else {
          await _jobDao.markCompleted(job.id);
        }
        return;
      }

      await _handleFailure(
        job,
        log.id,
        result.error ?? 'Scheduler task failed',
      );
    } catch (error) {
      await _handleFailure(job, log.id, error.toString());
    }
  }

  Future<void> _handleFailure(
    SchedulerJobRecord job,
    String logId,
    String error,
  ) async {
    await _runLogDao.finish(logId, status: 'failed', error: error);
    final retryCount = job.retryCount + 1;
    await _jobDao.reschedule(
      job.id,
      runAfter: _policy.retryRunAfterMillis(retryCount - 1, DateTime.now()),
      status: 'pending',
      retryCount: retryCount,
      lastError: error,
    );
  }
}
