import 'dart:async';
import 'dart:developer' as developer;

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';
import 'cloud_storage.dart';
import '../database/database_service.dart';

class AutoBackupService {
  static final AutoBackupService _instance = AutoBackupService._internal();
  factory AutoBackupService() => _instance;
  AutoBackupService._internal();

  Timer? _timer;
  bool _running = false;
  final BackupService _backupService = BackupService();

  void init() {
    if (_running) return;
    _running = true;
    _scheduleNext();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _scheduleNext() async {
    final prefs = await SharedPreferences.getInstance();
    final intervalMinutes = prefs.getInt('auto_backup_interval') ?? 0;
    if (intervalMinutes <= 0) return;

    _timer?.cancel();
    _timer = Timer(Duration(minutes: intervalMinutes), _runBackup);
  }

  Future<void> _runBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_backup_enabled') ?? false;
      if (!enabled) return;

      final lastHash = prefs.getString('auto_backup_last_hash');
      final db = await DatabaseService().database;
      final tables = {
        'messages': 'created_at',
        'moments': 'created_at',
        'contacts': 'updated_at',
      };
      final hashes = <String>[];
      for (final entry in tables.entries) {
        final table = entry.key;
        final timestampColumn = entry.value;
        final row = (await db.rawQuery(
          'SELECT COUNT(*) AS count, MAX($timestampColumn) AS max_timestamp FROM $table',
        )).first;
        hashes.add('$table:${row['count']}:${row['max_timestamp']}');
      }
      final currentHash = hashes.join('|');
      if (currentHash == lastHash) return;

      final cloudType = prefs.getString('auto_backup_cloud_type');
      if (cloudType == null) return;

      final tempDir = (await getTemporaryDirectory()).path;
      final path = await _backupService.exportToZip(
        sections: BackupSection.values.toSet(),
        targetDir: tempDir,
      );

      CloudStorage? storage;
      if (cloudType == 'webdav') {
        final url = prefs.getString('auto_backup_webdav_url') ?? '';
        final username = prefs.getString('auto_backup_webdav_username') ?? '';
        final password = prefs.getString('auto_backup_webdav_password') ?? '';
        if (url.isNotEmpty && username.isNotEmpty) {
          storage = WebDavStorage(
            WebDavConfig(url: url, username: username, password: password),
          );
        }
      } else if (cloudType == 's3') {
        storage = S3Storage(
          S3Config(
            endpoint: prefs.getString('auto_backup_s3_endpoint') ?? '',
            region: prefs.getString('auto_backup_s3_region') ?? '',
            accessKey: prefs.getString('auto_backup_s3_access_key') ?? '',
            secretKey: prefs.getString('auto_backup_s3_secret_key') ?? '',
            bucket: prefs.getString('auto_backup_s3_bucket') ?? '',
          ),
        );
      }

      if (storage != null) {
        final fileName = path.split('/').last;
        final success = await storage.upload(path, fileName);
        if (success) {
          await prefs.setString('auto_backup_last_hash', currentHash);
          await prefs.setString(
            'auto_backup_last_time',
            DateTime.now().toIso8601String(),
          );
          await prefs.remove('auto_backup_last_error');
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Auto backup failed',
        name: 'AutoBackupService',
        error: e,
        stackTrace: stackTrace,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auto_backup_last_error', e.toString());
    } finally {
      if (_running) await _scheduleNext();
    }
  }
}
