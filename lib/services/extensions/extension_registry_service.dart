import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_paths.dart';
import '../../models/extension_manifest.dart';
import 'extension_manifest_parser.dart';

class InstalledExtension {
  final ExtensionManifest manifest;
  final Directory directory;
  final bool enabled;
  final String? lastError;

  const InstalledExtension({
    required this.manifest,
    required this.directory,
    required this.enabled,
    this.lastError,
  });
}

class ExtensionRegistryService {
  final Future<AppPaths> Function() createAppPaths;
  final Future<SharedPreferences> Function() loadPrefs;
  final ExtensionManifestParser parser;

  ExtensionRegistryService({
    Future<AppPaths> Function()? createAppPaths,
    Future<SharedPreferences> Function()? loadPrefs,
    ExtensionManifestParser? parser,
  }) : createAppPaths = createAppPaths ?? AppPaths.create,
       loadPrefs = loadPrefs ?? SharedPreferences.getInstance,
       parser = parser ?? ExtensionManifestParser();

  static const _enabledKey = 'extension_registry_enabled';
  static const _lastErrorKey = 'extension_registry_last_error';

  Future<List<InstalledExtension>> scan() async {
    final paths = await createAppPaths();
    await paths.ensureInitialized();
    final prefs = await loadPrefs();
    final enabled = _stringBoolMap(prefs.getString(_enabledKey));
    final errors = _stringStringMap(prefs.getString(_lastErrorKey));
    final root = paths.extensions;
    if (!await root.exists()) return const [];

    final result = <InstalledExtension>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      try {
        final manifest = await parser.parseDirectory(entity);
        result.add(
          InstalledExtension(
            manifest: manifest,
            directory: entity,
            enabled: enabled[manifest.id] ?? false,
            lastError: errors[manifest.id],
          ),
        );
      } catch (e) {
        final id = p.basename(entity.path);
        errors[id] = e.toString();
      }
    }
    await prefs.setString(_lastErrorKey, jsonEncode(errors));
    result.sort((a, b) {
      final order = a.manifest.loadingOrder.compareTo(b.manifest.loadingOrder);
      if (order != 0) return order;
      return a.manifest.displayName.compareTo(b.manifest.displayName);
    });
    return result;
  }

  Future<List<InstalledExtension>> enabledExtensions() async {
    final extensions = await scan();
    return extensions.where((extension) => extension.enabled).toList();
  }

  Future<void> setEnabled(String id, bool value) async {
    final prefs = await loadPrefs();
    final enabled = _stringBoolMap(prefs.getString(_enabledKey));
    enabled[id] = value;
    await prefs.setString(_enabledKey, jsonEncode(enabled));
  }

  Future<void> setLastError(String id, String? error) async {
    final prefs = await loadPrefs();
    final errors = _stringStringMap(prefs.getString(_lastErrorKey));
    if (error == null) {
      errors.remove(id);
    } else {
      errors[id] = error;
    }
    await prefs.setString(_lastErrorKey, jsonEncode(errors));
  }

  Future<void> uninstall(String id) async {
    final paths = await createAppPaths();
    await paths.ensureInitialized();
    final targetDirectory = Directory(p.join(paths.extensions.path, id));
    if (await targetDirectory.exists()) {
      await targetDirectory.delete(recursive: true);
    }
    final prefs = await loadPrefs();
    final enabled = _stringBoolMap(prefs.getString(_enabledKey));
    final errors = _stringStringMap(prefs.getString(_lastErrorKey));
    enabled.remove(id);
    errors.remove(id);
    await prefs.setString(_enabledKey, jsonEncode(enabled));
    await prefs.setString(_lastErrorKey, jsonEncode(errors));
  }

  Future<void> clearLastError(String id) => setLastError(id, null);

  Future<void> installFromManifest(File manifestFile) async {
    final sourceDirectory = manifestFile.parent;
    final manifest = await parser.parseDirectory(sourceDirectory);
    final paths = await createAppPaths();
    await paths.ensureInitialized();
    final targetDirectory = Directory(
      p.join(paths.extensions.path, manifest.id),
    );
    if (p.normalize(sourceDirectory.path) ==
        p.normalize(targetDirectory.path)) {
      return;
    }
    if (await targetDirectory.exists()) {
      await targetDirectory.delete(recursive: true);
    }
    await _copyDirectory(sourceDirectory, targetDirectory);
  }

  Future<Map<String, String>> loadScripts(InstalledExtension extension) async {
    final scripts = <String, String>{};
    for (final js in extension.manifest.js) {
      scripts[js] = await File(
        p.join(extension.directory.path, js),
      ).readAsString();
    }
    return scripts;
  }

  static Map<String, bool> _stringBoolMap(String? source) {
    if (source == null) return <String, bool>{};
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value == true));
  }

  static Map<String, String> _stringStringMap(String? source) {
    if (source == null) return <String, String>{};
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      final relative = p.relative(entity.path, from: source.path);
      final destination = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        await File(destination).parent.create(recursive: true);
        await entity.copy(destination);
      }
    }
  }
}
