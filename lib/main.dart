import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'router.dart';
import 'theme/wechat_theme.dart';
import 'providers/contacts_provider.dart';
import 'providers/settings_provider.dart';
import 'services/proactive/proactive_service.dart';
import 'services/update/update_service.dart';
import 'services/backup/auto_backup_service.dart';
import 'services/scheduler/unified_scheduler.dart';
import 'services/st_compat/compat_storage_bootstrap_service.dart';
import 'services/extensions/extension_bridge_service.dart';
import 'services/extensions/extension_event_bus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite on desktop (Windows/Linux) requires FFI initialization because
  // there is no native platform plugin.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final container = ProviderContainer();

  unawaited(
    CompatStorageBootstrapService.create().then(
      (service) => service.initializeAndRebuildIndex(),
    ),
  );

  unawaited(
    ExtensionBridgeService().initialize().then((bridge) async {
      await bridge.loadEnabledExtensions();
      ExtensionEventBus.instance.publishType('app_ready');
    }),
  );

  final proactive = ProactiveService();
  proactive.init();
  proactive.onNewMessage = () =>
      container.read(contactsProvider.notifier).refresh();
  proactive.checkOnAppOpen();

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('check_update_on_startup') ?? false) {
    UpdateService().checkUpdate();
  }

  UnifiedScheduler.instance.start(
    handlers: [
      AutoBackupTaskHandler(),
      ProactiveCheckTaskHandler(service: proactive),
      MomentsCycleTaskHandler(service: proactive),
    ],
  );
  await AutoBackupService().init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: SoulTalkApp(container: container),
    ),
  );
}

class SoulTalkApp extends ConsumerStatefulWidget {
  final ProviderContainer container;

  const SoulTalkApp({super.key, required this.container});

  @override
  ConsumerState<SoulTalkApp> createState() => _SoulTalkAppState();
}

class _SoulTalkAppState extends ConsumerState<SoulTalkApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ProactiveService().dispose();
    UnifiedScheduler.instance.stop();
    AutoBackupService().dispose();
    widget.container.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final proactive = ProactiveService();
    if (state == AppLifecycleState.paused) {
      // 用户进入后台 → 记录离开时间
      proactive.recordUserActive();
    } else if (state == AppLifecycleState.resumed) {
      // 用户返回前台 → 校验是否需要自动行为
      proactive.checkOnAppOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final isDark = settings?.darkMode ?? false;

    return MaterialApp.router(
      title: 'SoulTalk',
      theme: WeChatTheme.light,
      darkTheme: WeChatTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
