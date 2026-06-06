import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class STWorldIndexRecord {
  final String worldId;
  final String name;
  final String filePath;
  final int entryCount;
  final int updatedAt;

  const STWorldIndexRecord({
    required this.worldId,
    required this.name,
    required this.filePath,
    required this.entryCount,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'world_id': worldId,
    'name': name,
    'file_path': filePath,
    'entry_count': entryCount,
    'updated_at': updatedAt,
  };

  factory STWorldIndexRecord.fromMap(Map<String, Object?> map) {
    return STWorldIndexRecord(
      worldId: map['world_id']! as String,
      name: map['name']! as String,
      filePath: map['file_path']! as String,
      entryCount: map['entry_count'] as int? ?? 0,
      updatedAt: map['updated_at']! as int,
    );
  }
}

class STWorldIndexDao {
  final DatabaseService _db;

  STWorldIndexDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> replaceAll(List<STWorldIndexRecord> records) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('st_world_index');
      for (final record in records) {
        await txn.insert('st_world_index', record.toMap());
      }
    });
  }

  Future<List<STWorldIndexRecord>> getAll() async {
    final db = await _database;
    final rows = await db.query('st_world_index', orderBy: 'name ASC');
    return rows.map(STWorldIndexRecord.fromMap).toList();
  }
}
