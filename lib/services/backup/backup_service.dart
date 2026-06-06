import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/app_paths.dart';
import '../../core/file_store/atomic_file_writer.dart';
import '../database/database_service.dart';
import '../st_compat/compat_storage_bootstrap_service.dart';
import 'backup_encryption.dart';

enum BackupSection {
  apiConfigs,
  contacts,
  messages,
  moments,
  settings,
  presets,
  regexScripts,
  memoryEntries,
  compatFiles,
  attachments,
}

extension BackupSectionLabel on BackupSection {
  String get label => switch (this) {
    BackupSection.apiConfigs => 'API 配置',
    BackupSection.contacts => '联系人',
    BackupSection.messages => '聊天记录',
    BackupSection.moments => '朋友圈',
    BackupSection.settings => '应用设置',
    BackupSection.presets => '对话预设',
    BackupSection.regexScripts => '正则脚本',
    BackupSection.memoryEntries => '记忆表格',
    BackupSection.compatFiles => 'SillyTavern compat files',
    BackupSection.attachments => 'Attachments',
  };

  String get folderName => switch (this) {
    BackupSection.apiConfigs => 'api',
    BackupSection.contacts => 'contacts',
    BackupSection.messages => 'messages',
    BackupSection.moments => 'moments',
    BackupSection.settings => 'settings',
    BackupSection.presets => 'presets',
    BackupSection.regexScripts => 'regex',
    BackupSection.memoryEntries => 'memory',
    BackupSection.compatFiles => 'st_compat',
    BackupSection.attachments => 'attachments',
  };
}

class BackupRestoreReport {
  final bool success;
  final String? error;
  final Map<BackupSection, int> restoredRows;
  final Map<BackupSection, int> restoredFiles;
  final List<String> details;

  const BackupRestoreReport({
    required this.success,
    this.error,
    this.restoredRows = const {},
    this.restoredFiles = const {},
    this.details = const [],
  });

  int rowsFor(BackupSection section) => restoredRows[section] ?? 0;
  int filesFor(BackupSection section) => restoredFiles[section] ?? 0;
}

class BackupService {
  final DatabaseService _dbService;
  final AtomicFileWriter _atomicFileWriter;
  final Future<void> Function()? _rebuildIndexes;
  final Future<AppPaths> Function() _createAppPaths;

  BackupService({
    DatabaseService? dbService,
    AtomicFileWriter? atomicFileWriter,
    Future<void> Function()? rebuildIndexes,
    Future<AppPaths> Function()? createAppPaths,
  }) : _dbService = dbService ?? DatabaseService(),
       _atomicFileWriter = atomicFileWriter ?? AtomicFileWriter(),
       _rebuildIndexes = rebuildIndexes,
       _createAppPaths = createAppPaths ?? AppPaths.create;

  Future<String> exportToZip({
    required Set<BackupSection> sections,
    required String targetDir,
    String? password,
  }) async {
    final db = await _dbService.database;
    final archive = Archive();
    final manifestFiles = <Map<String, Object?>>[];
    final paths = await _createAppPaths();

    for (final section in sections) {
      final folder = section.folderName;
      switch (section) {
        case BackupSection.apiConfigs:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/api_configs.json',
            'section',
            await db.query('api_configs'),
          );
        case BackupSection.contacts:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/contacts.json',
            'section',
            await db.query('contacts'),
          );
        case BackupSection.messages:
          final contacts = await db.query('contacts');
          for (final c in contacts) {
            final rows = await db.query(
              'messages',
              where: 'contact_id = ?',
              whereArgs: [c['id']],
            );
            if (rows.isEmpty) continue;
            final safeId = (c['id'] as String).replaceAll(
              RegExp(r'[^\w\-]'),
              '_',
            );
            _addBytesFile(
              archive,
              manifestFiles,
              '$folder/$safeId.json',
              utf8.encode(jsonEncode(rows)),
              'section',
            );
          }
        case BackupSection.moments:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/moments.json',
            'section',
            await db.query('moments'),
          );
        case BackupSection.settings:
          final prefs = await SharedPreferences.getInstance();
          final settings = <String, dynamic>{};
          for (final key in prefs.getKeys()) {
            settings[key] = prefs.get(key);
          }
          _addBytesFile(
            archive,
            manifestFiles,
            '$folder/settings.json',
            utf8.encode(jsonEncode(settings)),
            'section',
          );
        case BackupSection.presets:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/presets.json',
            'section',
            await db.query('chat_presets'),
          );
        case BackupSection.regexScripts:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/regex_scripts.json',
            'section',
            await db.query('regex_scripts'),
          );
        case BackupSection.memoryEntries:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/memory_entries.json',
            'section',
            await db.query('memory_entries'),
          );
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/memory_states.json',
            'section',
            await db.query('memory_states'),
          );
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/memory_cards.json',
            'section',
            await db.query('memory_cards'),
          );
        case BackupSection.compatFiles:
          await _addDirectoryToArchive(
            archive,
            manifestFiles,
            paths.stCompat,
            'st_compat',
            'st_compat',
          );
        case BackupSection.attachments:
          await _addDirectoryToArchive(
            archive,
            manifestFiles,
            paths.attachments,
            'soultalk/attachments',
            'attachments',
          );
      }
    }

    final manifest = {
      'version': '1.1',
      'app': 'soultalk',
      'exported_at': DateTime.now().toIso8601String(),
      'sections': sections.map((s) => s.folderName).toList(),
      'files': manifestFiles,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipBytes = ZipEncoder().encode(archive);

    if (password != null && password.isNotEmpty) {
      final encrypted = BackupEncryption.encrypt(
        Uint8List.fromList(zipBytes),
        password,
      );
      final zipPath = p.join(targetDir, 'soultalk_backup_$timestamp.enc.zip');
      await File(zipPath).writeAsBytes(encrypted);
      return zipPath;
    }

    final zipPath = p.join(targetDir, 'soultalk_backup_$timestamp.zip');
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }

  Future<bool> importFromZip({
    required String zipPath,
    required Set<BackupSection> sections,
    String? password,
  }) async {
    return (await importFromZipWithReport(
      zipPath: zipPath,
      sections: sections,
      password: password,
    )).success;
  }

  Future<BackupRestoreReport> importFromZipWithReport({
    required String zipPath,
    required Set<BackupSection> sections,
    String? password,
  }) async {
    final restoredRows = <BackupSection, int>{};
    final restoredFiles = <BackupSection, int>{};
    final details = <String>[];
    void addRows(BackupSection section, int count) {
      restoredRows[section] = (restoredRows[section] ?? 0) + count;
    }

    void addFiles(BackupSection section, int count) {
      restoredFiles[section] = (restoredFiles[section] ?? 0) + count;
    }

    try {
      var bytes = await File(zipPath).readAsBytes();
      final isEnc = zipPath.endsWith('.enc.zip');

      if (isEnc) {
        if (password == null || password.isEmpty) {
          return const BackupRestoreReport(success: false, error: '缺少备份密码');
        }
        try {
          bytes = BackupEncryption.decrypt(Uint8List.fromList(bytes), password);
        } catch (_) {
          return const BackupRestoreReport(
            success: false,
            error: '备份密码错误或文件已损坏',
          );
        }
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = _readManifest(archive);
      if (manifest == null || manifest['app'] != 'soultalk') {
        return const BackupRestoreReport(
          success: false,
          error: '不是有效的 SoulTalk 备份',
        );
      }
      _validateManifestFiles(archive, manifest);
      details.add('Manifest ${manifest['version'] ?? 'unknown'} 校验通过');
      await _createRestorePoint();
      details.add('已创建本地恢复点');

      final db = await _dbService.database;

      for (final section in sections) {
        final folder = section.folderName;
        switch (section) {
          case BackupSection.apiConfigs:
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/api_configs.json',
                'api_configs',
              ),
            );
          case BackupSection.contacts:
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/contacts.json',
                'contacts',
              ),
            );
          case BackupSection.messages:
            for (final file in archive.files) {
              if (!file.isFile ||
                  !file.name.startsWith('$folder/') ||
                  !file.name.endsWith('.json')) {
                continue;
              }
              addRows(
                section,
                await _restoreRows(db, archive, file.name, 'messages'),
              );
            }
          case BackupSection.moments:
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/moments.json',
                'moments',
              ),
            );
          case BackupSection.settings:
            final file = archive.findFile('$folder/settings.json');
            if (file != null) {
              final settings =
                  jsonDecode(_contentString(file)) as Map<String, dynamic>;
              final prefs = await SharedPreferences.getInstance();
              var count = 0;
              for (final entry in settings.entries) {
                final v = entry.value;
                if (v is int) {
                  await prefs.setInt(entry.key, v);
                  count++;
                } else if (v is double) {
                  await prefs.setDouble(entry.key, v);
                  count++;
                } else if (v is bool) {
                  await prefs.setBool(entry.key, v);
                  count++;
                } else if (v is String) {
                  await prefs.setString(entry.key, v);
                  count++;
                }
              }
              addRows(section, count);
            }
          case BackupSection.presets:
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/presets.json',
                'chat_presets',
              ),
            );
          case BackupSection.regexScripts:
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/regex_scripts.json',
                'regex_scripts',
              ),
            );
          case BackupSection.memoryEntries:
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/memory_entries.json',
                'memory_entries',
              ),
            );
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/memory_states.json',
                'memory_states',
              ),
            );
            addRows(
              section,
              await _restoreRows(
                db,
                archive,
                '$folder/memory_cards.json',
                'memory_cards',
              ),
            );
          case BackupSection.compatFiles:
            final paths = await _createAppPaths();
            addFiles(
              section,
              await _restoreArchiveDirectory(
                archive,
                'st_compat',
                paths.stCompat,
              ),
            );
          case BackupSection.attachments:
            final paths = await _createAppPaths();
            addFiles(
              section,
              await _restoreArchiveDirectory(
                archive,
                'soultalk/attachments',
                paths.attachments,
              ),
            );
        }
      }

      if (sections.contains(BackupSection.compatFiles) ||
          sections.contains(BackupSection.attachments)) {
        await _rebuildRestoredIndexes();
        details.add('已重建文件索引');
      }
      return BackupRestoreReport(
        success: true,
        restoredRows: restoredRows,
        restoredFiles: restoredFiles,
        details: details,
      );
    } catch (e) {
      return BackupRestoreReport(
        success: false,
        error: e.toString(),
        details: details,
      );
    }
  }

  Future<void> _addJsonRowsFile(
    Archive archive,
    List<Map<String, Object?>> manifestFiles,
    String archivePath,
    String domain,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return;
    _addBytesFile(
      archive,
      manifestFiles,
      archivePath,
      utf8.encode(jsonEncode(rows)),
      domain,
    );
  }

  void _addBytesFile(
    Archive archive,
    List<Map<String, Object?>> manifestFiles,
    String archivePath,
    List<int> bytes,
    String domain, {
    int? mtime,
  }) {
    archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
    manifestFiles.add({
      'archive_path': archivePath,
      'domain': domain,
      'sha256': sha256.convert(bytes).toString(),
      'size': bytes.length,
      'mtime': mtime ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    List<Map<String, Object?>> manifestFiles,
    Directory directory,
    String archiveRoot,
    String domain,
  ) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      final relative = p
          .relative(entity.path, from: directory.path)
          .split(p.separator)
          .join('/');
      final stat = await entity.stat();
      _addBytesFile(
        archive,
        manifestFiles,
        '$archiveRoot/$relative',
        bytes,
        domain,
        mtime: stat.modified.millisecondsSinceEpoch,
      );
    }
  }

  Future<int> _restoreArchiveDirectory(
    Archive archive,
    String archiveRoot,
    Directory targetRoot,
  ) async {
    var count = 0;
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('$archiveRoot/')) continue;
      final relative = file.name.substring(archiveRoot.length + 1);
      _validateRelativeArchivePath(relative);
      final target = _safeTargetFile(targetRoot, relative);
      await _atomicFileWriter.writeAsBytes(
        target,
        Uint8List.fromList(_contentBytes(file)),
      );
      count++;
    }
    return count;
  }

  Future<int> _restoreRows(
    Database db,
    Archive archive,
    String archivePath,
    String table,
  ) async {
    final file = archive.findFile(archivePath);
    if (file == null) return 0;
    final rows = jsonDecode(_contentString(file)) as List;
    for (final row in rows) {
      await db.insert(
        table,
        row as Map<String, dynamic>,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return rows.length;
  }

  Map<String, dynamic>? _readManifest(Archive archive) {
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) return null;
    return jsonDecode(_contentString(manifestFile)) as Map<String, dynamic>;
  }

  void _validateManifestFiles(Archive archive, Map<String, dynamic> manifest) {
    if (manifest['version'] == '1.0') return;
    final files = manifest['files'];
    if (files is! List) throw const FormatException('Invalid manifest files');
    for (final entry in files) {
      if (entry is! Map) throw const FormatException('Invalid manifest entry');
      final archivePath = entry['archive_path'];
      final expectedSha = entry['sha256'];
      final expectedSize = entry['size'];
      if (archivePath is! String ||
          expectedSha is! String ||
          expectedSize is! int) {
        throw const FormatException('Invalid manifest entry fields');
      }
      _validateArchivePath(archivePath);
      final file = archive.findFile(archivePath);
      if (file == null || !file.isFile) {
        throw FormatException('Missing archive file: $archivePath');
      }
      final bytes = _contentBytes(file);
      if (bytes.length != expectedSize) {
        throw FormatException('Size mismatch: $archivePath');
      }
      if (sha256.convert(bytes).toString() != expectedSha) {
        throw FormatException('Hash mismatch: $archivePath');
      }
    }
  }

  Future<void> _createRestorePoint() async {
    final paths = await _createAppPaths();
    final dir = Directory(p.join(paths.soultalk.path, 'restore_points'));
    await dir.create(recursive: true);
    await exportToZip(
      sections: BackupSection.values.toSet(),
      targetDir: dir.path,
    );
  }

  Future<void> _rebuildRestoredIndexes() async {
    if (_rebuildIndexes != null) {
      await _rebuildIndexes();
      return;
    }
    final bootstrap = await CompatStorageBootstrapService.create();
    await bootstrap.initializeAndRebuildIndex();
  }

  void _validateArchivePath(String archivePath) {
    if (archivePath.isEmpty ||
        archivePath.contains('\\') ||
        p.isAbsolute(archivePath)) {
      throw FormatException('Invalid archive path: $archivePath');
    }
    _validateRelativeArchivePath(archivePath);
  }

  void _validateRelativeArchivePath(String relative) {
    final parts = relative.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('Invalid archive path: $relative');
    }
  }

  File _safeTargetFile(Directory targetRoot, String relative) {
    final target = File(p.joinAll([targetRoot.path, ...relative.split('/')]));
    final rootPath = p.normalize(targetRoot.absolute.path);
    final targetPath = p.normalize(target.absolute.path);
    if (targetPath != rootPath && !p.isWithin(rootPath, targetPath)) {
      throw FormatException('Invalid restore target: $relative');
    }
    return target;
  }

  List<int> _contentBytes(ArchiveFile file) => file.content as List<int>;

  String _contentString(ArchiveFile file) => utf8.decode(_contentBytes(file));

  Future<List<BackupSection>> listSections(
    String zipPath, {
    String? password,
  }) async {
    try {
      var bytes = await File(zipPath).readAsBytes();

      if (zipPath.endsWith('.enc.zip')) {
        if (password == null || password.isEmpty) return [];
        try {
          bytes = BackupEncryption.decrypt(Uint8List.fromList(bytes), password);
        } catch (_) {
          return [];
        }
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = _readManifest(archive);
      if (manifest == null) return [];
      final sectionNames =
          (manifest['sections'] as List?)?.cast<String>() ?? [];

      return sectionNames
          .map(
            (name) =>
                BackupSection.values.firstWhere((s) => s.folderName == name),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}
