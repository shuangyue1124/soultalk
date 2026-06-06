import 'dart:convert';
import 'dart:io';

import '../../models/extension_manifest.dart';

class ExtensionManifestParser {
  Future<ExtensionManifest> parseDirectory(Directory directory) async {
    final manifestFile = File('${directory.path}/manifest.json');
    if (!await manifestFile.exists()) {
      throw const FormatException('manifest.json not found');
    }
    final manifest = ExtensionManifest.fromJson(
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
    );
    for (final js in manifest.js) {
      if (!await File('${directory.path}/$js').exists()) {
        throw FormatException('JS entry not found: $js');
      }
    }
    return manifest;
  }
}
