import 'dart:async';

import '../../models/extension_event.dart';
import '../../models/extension_manifest.dart';
import 'extension_event_bus.dart';
import 'extension_registry_service.dart';
import 'guarded_extension_sandbox_adapter.dart';
import 'extension_sandbox_adapter.dart';

class ExtensionBridgeService {
  final ExtensionEventBus eventBus;
  final ExtensionSandboxAdapter sandbox;
  StreamSubscription<ExtensionEvent>? _subscription;

  ExtensionBridgeService({
    ExtensionEventBus? eventBus,
    ExtensionSandboxAdapter? sandbox,
  }) : eventBus = eventBus ?? ExtensionEventBus.instance,
       sandbox = sandbox ?? GuardedExtensionSandboxAdapter();

  Future<ExtensionBridgeService> initialize() async {
    await sandbox.initialize();
    _subscription ??= eventBus.events.listen(sandbox.emitEvent);
    return this;
  }

  Future<void> loadExtension(
    ExtensionManifest manifest,
    Map<String, String> scripts,
  ) async {
    for (final js in manifest.js) {
      final source = scripts[js];
      if (source == null) throw ArgumentError('Missing script: $js');
      await sandbox.loadScript(manifest.id, source);
    }
  }

  Future<void> loadEnabledExtensions({
    ExtensionRegistryService? registry,
  }) async {
    final service = registry ?? ExtensionRegistryService();
    final extensions = await service.enabledExtensions();
    for (final extension in extensions) {
      try {
        await loadExtension(
          extension.manifest,
          await service.loadScripts(extension),
        );
        await service.setLastError(extension.manifest.id, null);
      } catch (e) {
        await service.setLastError(extension.manifest.id, e.toString());
      }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await sandbox.dispose();
  }
}
