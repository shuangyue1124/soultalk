import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class FileManifestEntry {
  final String path;
  final String domain;
  final String sha256;
  final int mtime;
  final int size;

  const FileManifestEntry({
    required this.path,
    required this.domain,
    required this.sha256,
    required this.mtime,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'domain': domain,
    'sha256': sha256,
    'mtime': mtime,
    'size': size,
  };
}

class FileManifestService {
  Future<List<FileManifestEntry>> scan(Directory root) async {
    if (!await root.exists()) return const [];

    final entries = <FileManifestEntry>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      final relativePath = p
          .relative(entity.path, from: root.path)
          .replaceAll('\\', '/');
      entries.add(
        FileManifestEntry(
          path: relativePath,
          domain: _domainFor(relativePath),
          sha256: await _sha256(entity),
          mtime: stat.modified.millisecondsSinceEpoch,
          size: stat.size,
        ),
      );
    }
    entries.sort((a, b) => a.path.compareTo(b.path));
    return entries;
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String _domainFor(String relativePath) {
    final first = relativePath.split('/').first;
    return switch (first) {
      'characters' => 'character',
      'chats' => 'chat',
      'worlds' => 'world',
      'settings' => 'preset',
      'themes' => 'theme',
      'extensions' => 'extension',
      'plugins' => 'plugin',
      'user' => 'persona',
      'groups' => 'group',
      'avatars' => 'avatar',
      'thumbnails' => 'thumbnail',
      'attachments' => 'attachment',
      _ => first,
    };
  }

  String toJson(List<FileManifestEntry> entries) {
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'files': entries.map((entry) => entry.toJson()).toList(),
    });
  }
}
