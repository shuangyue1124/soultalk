import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class STPresetIndexRecord {
  final String presetId;
  final String apiId;
  final String name;
  final String filePath;
  final int updatedAt;

  const STPresetIndexRecord({
    required this.presetId,
    required this.apiId,
    required this.name,
    required this.filePath,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'preset_id': presetId,
    'api_id': apiId,
    'name': name,
    'file_path': filePath,
    'updated_at': updatedAt,
  };

  factory STPresetIndexRecord.fromMap(Map<String, Object?> map) {
    return STPresetIndexRecord(
      presetId: map['preset_id']! as String,
      apiId: map['api_id']! as String,
      name: map['name']! as String,
      filePath: map['file_path']! as String,
      updatedAt: map['updated_at']! as int,
    );
  }
}

class STPresetIndexDao {
  final DatabaseService _db;

  STPresetIndexDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> replaceAll(List<STPresetIndexRecord> records) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('st_preset_index');
      for (final record in records) {
        await txn.insert('st_preset_index', record.toMap());
      }
    });
  }

  Future<List<STPresetIndexRecord>> getAll() async {
    final db = await _database;
    final rows = await db.query(
      'st_preset_index',
      orderBy: 'api_id ASC, name ASC',
    );
    return rows.map(STPresetIndexRecord.fromMap).toList();
  }
}
