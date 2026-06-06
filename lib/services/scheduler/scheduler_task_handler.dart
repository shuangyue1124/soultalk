import '../database/scheduler_job_dao.dart';

abstract class SchedulerTaskHandler {
  String get type;

  Future<SchedulerTaskResult> run(SchedulerJobRecord job);
}

class SchedulerTaskResult {
  final bool success;
  final String? summary;
  final String? error;
  final int? nextRunAfterMillis;

  const SchedulerTaskResult.success({this.summary, this.nextRunAfterMillis})
    : success = true,
      error = null;

  const SchedulerTaskResult.failure({required String this.error, this.summary})
    : success = false,
      nextRunAfterMillis = null;
}
