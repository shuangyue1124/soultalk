import 'dart:convert';

import '../../models/extension_context.dart';

class SillyTavernCompat {
  String bootstrap(ExtensionContext context) {
    final contextJson = jsonEncode(context.toJson());
    return '''
globalThis.SillyTavern = globalThis.SillyTavern || {};
globalThis.SillyTavern.getContext = function () { return $contextJson; };
globalThis.getContext = globalThis.SillyTavern.getContext;
globalThis.eventSource = globalThis.eventSource || {
  on: function () {},
  off: function () {},
  emit: function () {}
};
globalThis.SillyTavern.eventSource = globalThis.eventSource;
globalThis.SillyTavern.extensionSettings = globalThis.SillyTavern.extensionSettings || {};
globalThis.SillyTavern.storage = globalThis.SillyTavern.storage || {
  getItem: function (key) { return globalThis.SillyTavern.extensionSettings[key]; },
  setItem: function (key, value) { globalThis.SillyTavern.extensionSettings[key] = value; },
  removeItem: function (key) { delete globalThis.SillyTavern.extensionSettings[key]; }
};
globalThis.SillyTavern.registerCommand = globalThis.SillyTavern.registerCommand || function () {};
globalThis.SillyTavern.callCommand = globalThis.SillyTavern.callCommand || function () {};
globalThis.extension_settings = globalThis.SillyTavern.extensionSettings;
''';
  }
}
