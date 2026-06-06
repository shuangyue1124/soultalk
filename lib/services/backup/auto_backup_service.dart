import 'dart:async';
import 'dart:developer' as developer;

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_service.dart';
import '../database/scheduler_job_dao.dart';
import '../scheduler/scheduler_task_handler.dart';
import 'backup_service.dart';
import 'cloud_storage.dart';

class AutoBackupRunResult {
  final bool success;
  final String summary;

  const AutoBackupRunResult({required this.success, required this.summary});
}

class AutoBackupService {
  static const jobType = 'auto_backup';
  static const jobTargetId = 'global';
  static const jobId = 'auto_backup_global';

  static final AutoBackupService _instance = AutoBackupService._internal();
  factory AutoBackupService() => _instance;
  AutoBackupService._internal();

  bool _running = false;
  final BackupService _backupService = BackupService();
  final SchedulerJobDao _schedulerJobDao = SchedulerJobDao(DatabaseService());

  Future<void> init() async {
    _running = true;
    await syncSchedule();
  }

  void dispose() {
    _running = false;
  }

  Future<void> syncSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('auto_backup_enabled') ?? false;
    final intervalMinutes = prefs.getInt('auto_backup_interval') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _schedulerJobDao.getByTypeTarget(
      jobType,
      jobTargetId,
    );

    if (!enabled || intervalMinutes <= 0) {
      if (existing != null) await _schedulerJobDao.disable(existing.id);
      return;
    }

    await _schedulerJobDao.upsert(
      SchedulerJobRecord(
        id: existing?.id ?? jobId,
        type: jobType,
        targetId: jobTargetId,
        runAfter: existing?.status == 'pending'
            ? existing!.runAfter
            : now + Duration(minutes: intervalMinutes).inMilliseconds,
        retryCount: existing?.retryCount ?? 0,
        status: 'pending',
        payload: '{}',
        lastError: null,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<AutoBackupRunResult> runOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_backup_enabled') ?? false;
      if (!enabled) {
        return const AutoBackupRunResult(success: true, summary: 'disabled');
      }

      final lastHash = prefs.getString('auto_backup_last_hash');
      final db = await DatabaseService().database;
      final tables = {
        'messages': 'created_at',
        'moments': 'created_at',
        'contacts': 'updated_at',
      };
      final hashes = <String>[];
      for (final entry in tables.entries) {
        final row = (await db.rawQuery(
          'SELECT COUNT(*) AS count, MAX(${entry.value}) AS max_timestamp FROM ${entry.key}',
        )).first;
        hashes.add('${entry.key}:${row['count']}:${row['max_timestamp']}');
      }
      final currentHash = hashes.join('|');
      if (currentHash == lastHash) {
        return const AutoBackupRunResult(success: true, summary: 'no changes');
      }

      final storage = await _createStorage(prefs);
      if (storage == null) {
        return const AutoBackupRunResult(
          success: true,
          summary: 'no cloud storage configured',
        );
      }

      final tempDir = (await getTemporaryDirectory()).path;
      final path = await _backupService.exportToZip(
        sections: BackupSection.values.toSet(),
        targetDir: tempDir,
      );

      final fileName = path.split('/').last;
      final success = await storage.upload(path, fileName);
      if (!success) {
        await prefs.setString('auto_backup_last_error', 'Upload failed');
        return const AutoBackupRunResult(
          success: false,
          summary: 'upload failed',
        );
      }

      await prefs.setString('auto_backup_last_hash', currentHash);
      await prefs.setString(
        'auto_backup_last_time',
        DateTime.now().toIso8601String(),
      );
      await prefs.remove('auto_backup_last_error');
      return const AutoBackupRunResult(success: true, summary: 'uploaded');
    } catch (e, stackTrace) {
      developer.log(
        'Auto backup failed',
        name: 'AutoBackupService',
        error: e,
        stackTrace: stackTrace,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auto_backup_last_error', e.toString());
      return AutoBackupRunResult(success: false, summary: e.toString());
    } finally {
      if (_running) await syncSchedule();
    }
  }

  Future<CloudStorage?> _createStorage(SharedPreferences prefs) async {
    final cloudType = prefs.getString('auto_backup_cloud_type');
    if (cloudType == 'webdav') {
      final url = prefs.getString('auto_backup_webdav_url') ?? '';
      final username = prefs.getString('auto_backup_webdav_username') ?? '';
      final password = prefs.getString('auto_backup_webdav_password') ?? '';
      if (url.isNotEmpty && username.isNotEmpty) {
        return WebDavStorage(
          WebDavConfig(url: url, username: username, password: password),
        );
      }
    } else if (cloudType == 's3') {
      final endpoint = prefs.getString('auto_backup_s3_endpoint') ?? '';
      final bucket = prefs.getString('auto_backup_s3_bucket') ?? '';
      if (endpoint.isNotEmpty && bucket.isNotEmpty) {
        return S3Storage(
          S3Config(
            endpoint: endpoint,
            region: prefs.getString('auto_backup_s3_region') ?? '',
            accessKey: prefs.getString('auto_backup_s3_access_key') ?? '',
            secretKey: prefs.getString('auto_backup_s3_secret_key') ?? '',
            bucket: bucket,
          ),
        );
      }
    }
    return null;
  }
}

class AutoBackupTaskHandler implements SchedulerTaskHandler {
  final AutoBackupService service;

  AutoBackupTaskHandler({AutoBackupService? service})
    : service = service ?? AutoBackupService();

  @override
  String get type => AutoBackupService.jobType;

  @override
  Future<SchedulerTaskResult> run(SchedulerJobRecord job) async {
    final result = await service.runOnce();
    final prefs = await SharedPreferences.getInstance();
    final intervalMinutes = prefs.getInt('auto_backup_interval') ?? 0;
    final nextRunAfterMillis = intervalMinutes > 0
        ? DateTime.now()
              .add(Duration(minutes: intervalMinutes))
              .millisecondsSinceEpoch
        : null;
    if (result.success) {
      return SchedulerTaskResult.success(
        summary: result.summary,
        nextRunAfterMillis: nextRunAfterMillis,
      );
    }
    return SchedulerTaskResult.failure(error: result.summary);
  }
}
