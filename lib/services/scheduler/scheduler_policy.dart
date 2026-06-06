class SchedulerPolicy {
  final Duration tickInterval;
  final int maxDueJobsPerTick;
  final List<Duration> retryDelays;

  const SchedulerPolicy({
    this.tickInterval = const Duration(minutes: 1),
    this.maxDueJobsPerTick = 5,
    this.retryDelays = const [
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ],
  });

  int retryRunAfterMillis(int retryCount, DateTime now) {
    final index = retryCount.clamp(0, retryDelays.length - 1);
    return now.add(retryDelays[index]).millisecondsSinceEpoch;
  }
}
