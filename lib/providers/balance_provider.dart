import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_config.dart';
import '../models/balance_info.dart';
import '../services/api/balance_service.dart';

final balanceServiceProvider = Provider<BalanceService>(
  (ref) => BalanceService(),
);

final balanceProvider =
    AsyncNotifierProviderFamily<BalanceNotifier, BalanceInfo?, String>(
      BalanceNotifier.new,
    );

/// Per-api-config balance state.
class BalanceNotifier extends FamilyAsyncNotifier<BalanceInfo?, String> {
  Timer? _timer;

  @override
  Future<BalanceInfo?> build(String apiConfigId) async {
    ref.onDispose(() => _timer?.cancel());
    return null; // Not fetched until manually triggered or first auto-check
  }

  Future<void> refresh(ApiConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(balanceServiceProvider)
          .queryBalance(config.baseUrl, config.apiKey);
    });
  }

  Future<void> setupAutoRefresh(ApiConfig config, int intervalMinutes) async {
    _timer?.cancel();
    if (intervalMinutes <= 0) return;

    // Initial fetch
    await refresh(config);

    _timer = Timer.periodic(Duration(minutes: intervalMinutes), (_) {
      refresh(config);
    });
  }

  void cancelTimer() {
    _timer?.cancel();
  }
}
