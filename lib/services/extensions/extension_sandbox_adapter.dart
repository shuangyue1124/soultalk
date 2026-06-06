import '../../models/extension_event.dart';

abstract class ExtensionSandboxAdapter {
  Future<void> initialize();
  Future<void> loadScript(String extensionId, String source);
  Future<Object?> evaluate(String code);
  Future<void> emitEvent(ExtensionEvent event);
  Future<void> dispose();
}

class NoopExtensionSandboxAdapter implements ExtensionSandboxAdapter {
  final loadedScripts = <String, String>{};
  final emittedEvents = <ExtensionEvent>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadScript(String extensionId, String source) async {
    loadedScripts[extensionId] = source;
  }

  @override
  Future<Object?> evaluate(String code) async => null;

  @override
  Future<void> emitEvent(ExtensionEvent event) async {
    emittedEvents.add(event);
  }

  @override
  Future<void> dispose() async {
    loadedScripts.clear();
    emittedEvents.clear();
  }
}
