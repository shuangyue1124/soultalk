import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/models/contact.dart';
import 'package:soultalk/models/message.dart';
import 'package:soultalk/services/extensions/extension_context_provider.dart';
import 'package:soultalk/services/extensions/extension_event_bus.dart';
import 'package:soultalk/services/extensions/extension_manifest_parser.dart';
import 'package:soultalk/services/extensions/guarded_extension_sandbox_adapter.dart';
import 'package:soultalk/services/extensions/extension_registry_service.dart';
import 'package:soultalk/services/extensions/extension_storage_service.dart';
import 'package:soultalk/services/extensions/silly_tavern_compat.dart';

void main() {
  test('parses extension manifest and validates js entries', () async {
    final dir = await Directory.systemTemp.createTemp('extension_manifest_');
    addTearDown(() async => dir.delete(recursive: true));
    await File('${dir.path}/manifest.json').writeAsString('''
{"display_name":"Demo","version":"1.0","js":["index.js"],"unknown":true}
''');
    await File('${dir.path}/index.js').writeAsString('console.log("ok")');

    final manifest = await ExtensionManifestParser().parseDirectory(dir);

    expect(manifest.id, 'demo');
    expect(manifest.displayName, 'Demo');
    expect(manifest.js, ['index.js']);
    expect(manifest.raw['unknown'], isTrue);
  });

  test(
    'registry scans installed extensions and toggles enabled state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('extension_registry_');
      addTearDown(() async => root.delete(recursive: true));
      final extensionDir = Directory('${root.path}/st_compat/extensions/demo');
      await extensionDir.create(recursive: true);
      await File('${extensionDir.path}/manifest.json').writeAsString('''
{"id":"demo","display_name":"Demo","version":"1.0","js":["index.js"]}
''');
      await File(
        '${extensionDir.path}/index.js',
      ).writeAsString('console.log("ok")');

      final registry = ExtensionRegistryService(
        createAppPaths: () async => AppPaths.fromRootForTesting(root),
      );

      var extensions = await registry.scan();
      expect(extensions, hasLength(1));
      expect(extensions.single.enabled, isFalse);

      await registry.setEnabled('demo', true);
      extensions = await registry.enabledExtensions();
      expect(extensions.single.manifest.id, 'demo');
      expect(
        await registry.loadScripts(extensions.single),
        contains('index.js'),
      );
    },
  );

  test('event bus publishes allowlisted events only', () async {
    final bus = ExtensionEventBus.instance;
    final events = <String>[];
    final sub = bus.events.listen((event) => events.add(event.type));
    addTearDown(sub.cancel);

    bus.publishType('message_sent');
    bus.publishType('not_allowed');
    await Future<void>.delayed(Duration.zero);

    expect(events, ['message_sent']);
  });

  test('context provider creates SillyTavern compatible context', () {
    final context = ExtensionContextProvider().build(
      contact: Contact(id: 'c1', name: 'Alice'),
      messages: [
        Message(
          id: 'm1',
          contactId: 'c1',
          role: MessageRole.user,
          content: 'hello',
        ),
      ],
    );

    final json = context.toJson();
    expect(json['app'], 'SoulTalk');
    expect(json['characterName'], 'Alice');
    expect((json['messages'] as List).single['content'], 'hello');
  });

  test('guarded sandbox loads safe scripts and rejects blocked APIs', () async {
    final sandbox = GuardedExtensionSandboxAdapter();
    await sandbox.initialize();

    await sandbox.loadScript('safe', 'globalThis.x = 1;');
    expect(sandbox.loadedScripts, contains('safe'));
    expect(
      () => sandbox.loadScript('blocked', 'fetch("https://example.com")'),
      throwsFormatException,
    );
  });

  test('extension storage keeps values per extension', () {
    final storage = ExtensionStorageService();

    storage.setValue('a', 'key', 'value');
    storage.setValue('b', 'key', 'other');

    expect(storage.getValue('a', 'key'), 'value');
    expect(storage.snapshot('b'), {'key': 'other'});
    storage.removeValue('a', 'key');
    expect(storage.getValue('a', 'key'), isNull);
  });

  test('SillyTavern compatibility bootstrap exposes getContext', () {
    final context = ExtensionContextProvider().build();
    final script = SillyTavernCompat().bootstrap(context);

    expect(script, contains('SillyTavern.getContext'));
    expect(script, contains('globalThis.getContext'));
    expect(script, contains('eventSource'));
    expect(script, contains('extensionSettings'));
    expect(script, contains('registerCommand'));
  });
}
