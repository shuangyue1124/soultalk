import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/services/database/scheduler_job_dao.dart';
import 'package:soultalk/services/proactive/proactive_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'proactive check handler schedules next fixed five minute run',
    () async {
      var runCount = 0;
      final handler = ProactiveCheckTaskHandler(
        runCheck: () async => runCount++,
      );
      final before = DateTime.now().add(const Duration(minutes: 5));

      final result = await handler.run(_job('proactive_check'));

      expect(runCount, 1);
      expect(result.success, isTrue);
      expect(result.summary, 'checked');
      expect(
        result.nextRunAfterMillis,
        greaterThanOrEqualTo(before.millisecondsSinceEpoch - 1000),
      );
    },
  );

  test('moments cycle handler uses configured interval for next run', () async {
    SharedPreferences.setMockInitialValues({'moments_interval_minutes': 15});
    var runCount = 0;
    final handler = MomentsCycleTaskHandler(runCycle: () async => runCount++);
    final before = DateTime.now().add(const Duration(minutes: 15));

    final result = await handler.run(_job('moments_cycle'));

    expect(runCount, 1);
    expect(result.success, isTrue);
    expect(result.summary, 'moments cycle completed');
    expect(
      result.nextRunAfterMillis,
      greaterThanOrEqualTo(before.millisecondsSinceEpoch - 1000),
    );
  });
}

SchedulerJobRecord _job(String type) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return SchedulerJobRecord(
    id: '$type-global',
    type: type,
    targetId: 'global',
    runAfter: now,
    retryCount: 0,
    status: 'running',
    payload: '{}',
    lastError: null,
    createdAt: now,
    updatedAt: now,
  );
}
