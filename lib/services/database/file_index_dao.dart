import 'package:sqflite/sqflite.dart';

import '../../../core/file_store/file_manifest_service.dart';
import 'database_service.dart';

class FileIndexRecord {
  final String path;
  final String domain;
  final String sha256;
  final int mtime;
  final int size;
  final String? versionVector;
  final bool deleted;
  final int updatedAt;

  const FileIndexRecord({
    required this.path,
    required this.domain,
    required this.sha256,
    required this.mtime,
    required this.size,
    required this.versionVector,
    required this.deleted,
    required this.updatedAt,
  });

  factory FileIndexRecord.fromManifest(FileManifestEntry entry) {
    return FileIndexRecord(
      path: entry.path,
      domain: entry.domain,
      sha256: entry.sha256,
      mtime: entry.mtime,
      size: entry.size,
      versionVector: null,
      deleted: false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory FileIndexRecord.fromMap(Map<String, Object?> map) {
    return FileIndexRecord(
      path: map['path']! as String,
      domain: map['domain']! as String,
      sha256: map['sha256']! as String,
      mtime: map['mtime']! as int,
      size: map['size']! as int,
      versionVector: map['version_vector'] as String?,
      deleted: (map['deleted'] as int? ?? 0) == 1,
      updatedAt: map['updated_at']! as int,
    );
  }

  Map<String, Object?> toMap() => {
    'path': path,
    'domain': domain,
    'sha256': sha256,
    'mtime': mtime,
    'size': size,
    'version_vector': versionVector,
    'deleted': deleted ? 1 : 0,
    'updated_at': updatedAt,
  };
}

class FileIndexDao {
  final DatabaseService _db;

  FileIndexDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> upsert(FileIndexRecord record) async {
    final db = await _database;
    await db.insert(
      'file_index',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<FileIndexRecord> records) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final record in records) {
        await txn.insert(
          'file_index',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> replaceActiveSet(List<FileIndexRecord> records) async {
    final db = await _database;
    final activePaths = records.map((record) => record.path).toSet();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'file_index',
        columns: ['path'],
        where: 'deleted = 0',
      );
      for (final row in existing) {
        final path = row['path']! as String;
        if (!activePaths.contains(path)) {
          await txn.update(
            'file_index',
            {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
            where: 'path = ?',
            whereArgs: [path],
          );
        }
      }
      for (final record in records) {
        await txn.insert(
          'file_index',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<FileIndexRecord?> getByPath(String path) async {
    final db = await _database;
    final rows = await db.query(
      'file_index',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FileIndexRecord.fromMap(rows.first);
  }

  Future<List<FileIndexRecord>> getByDomain(String domain) async {
    final db = await _database;
    final rows = await db.query(
      'file_index',
      where: 'domain = ? AND deleted = 0',
      whereArgs: [domain],
      orderBy: 'path ASC',
    );
    return rows.map(FileIndexRecord.fromMap).toList();
  }

  Future<List<FileIndexRecord>> getAllActive() async {
    final db = await _database;
    final rows = await db.query(
      'file_index',
      where: 'deleted = 0',
      orderBy: 'path ASC',
    );
    return rows.map(FileIndexRecord.fromMap).toList();
  }

  Future<void> markDeleted(String path) async {
    final db = await _database;
    await db.update(
      'file_index',
      {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'path = ?',
      whereArgs: [path],
    );
  }
}
