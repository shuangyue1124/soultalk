import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/extensions/extension_bridge_service.dart';
import '../services/extensions/extension_context_provider.dart';
import '../services/extensions/extension_event_bus.dart';

final extensionEventBusProvider = Provider<ExtensionEventBus>(
  (ref) => ExtensionEventBus.instance,
);

final extensionContextProvider = Provider<ExtensionContextProvider>(
  (ref) => ExtensionContextProvider(),
);

final extensionBridgeProvider = Provider<ExtensionBridgeService>((ref) {
  final service = ExtensionBridgeService(
    eventBus: ref.read(extensionEventBusProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
