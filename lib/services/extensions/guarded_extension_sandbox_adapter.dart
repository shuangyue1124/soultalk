import 'dart:async';

import '../../models/extension_event.dart';
import 'extension_sandbox_adapter.dart';

class GuardedExtensionSandboxAdapter implements ExtensionSandboxAdapter {
  final Duration timeout;
  final Map<String, String> loadedScripts = {};
  final List<ExtensionEvent> emittedEvents = [];
  bool _initialized = false;

  GuardedExtensionSandboxAdapter({this.timeout = const Duration(seconds: 2)});

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> loadScript(String extensionId, String source) async {
    _ensureInitialized();
    _validateSource(source);
    await Future<void>.delayed(Duration.zero).timeout(timeout);
    loadedScripts[extensionId] = source;
  }

  @override
  Future<Object?> evaluate(String code) async {
    _ensureInitialized();
    _validateSource(code);
    await Future<void>.delayed(Duration.zero).timeout(timeout);
    return null;
  }

  @override
  Future<void> emitEvent(ExtensionEvent event) async {
    _ensureInitialized();
    emittedEvents.add(event);
  }

  @override
  Future<void> dispose() async {
    loadedScripts.clear();
    emittedEvents.clear();
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Extension sandbox is not initialized');
    }
  }

  void _validateSource(String source) {
    final blocked = RegExp(
      r'\b(XMLHttpRequest|fetch|WebSocket|importScripts|eval|Function)\b',
    );
    if (blocked.hasMatch(source)) {
      throw const FormatException('Extension script uses blocked runtime API');
    }
  }
}
