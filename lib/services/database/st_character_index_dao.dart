import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class STCharacterIndexRecord {
  final String characterId;
  final String name;
  final String filePath;
  final String? spec;
  final String? specVersion;
  final String? avatarPath;
  final String? tags;
  final String? creator;
  final String? characterVersion;
  final bool favorite;
  final bool pinned;
  final int unreadCount;
  final int updatedAt;

  const STCharacterIndexRecord({
    required this.characterId,
    required this.name,
    required this.filePath,
    required this.spec,
    required this.specVersion,
    required this.avatarPath,
    required this.tags,
    required this.creator,
    required this.characterVersion,
    required this.favorite,
    required this.pinned,
    required this.unreadCount,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'character_id': characterId,
    'name': name,
    'file_path': filePath,
    'spec': spec,
    'spec_version': specVersion,
    'avatar_path': avatarPath,
    'tags': tags,
    'creator': creator,
    'character_version': characterVersion,
    'favorite': favorite ? 1 : 0,
    'pinned': pinned ? 1 : 0,
    'unread_count': unreadCount,
    'updated_at': updatedAt,
  };

  factory STCharacterIndexRecord.fromMap(Map<String, Object?> map) {
    return STCharacterIndexRecord(
      characterId: map['character_id']! as String,
      name: map['name']! as String,
      filePath: map['file_path']! as String,
      spec: map['spec'] as String?,
      specVersion: map['spec_version'] as String?,
      avatarPath: map['avatar_path'] as String?,
      tags: map['tags'] as String?,
      creator: map['creator'] as String?,
      characterVersion: map['character_version'] as String?,
      favorite: (map['favorite'] as int? ?? 0) == 1,
      pinned: (map['pinned'] as int? ?? 0) == 1,
      unreadCount: map['unread_count'] as int? ?? 0,
      updatedAt: map['updated_at']! as int,
    );
  }
}

class STCharacterIndexDao {
  final DatabaseService _db;

  STCharacterIndexDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> replaceAll(List<STCharacterIndexRecord> records) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('st_character_index');
      for (final record in records) {
        await txn.insert('st_character_index', record.toMap());
      }
    });
  }

  Future<List<STCharacterIndexRecord>> getAll() async {
    final db = await _database;
    final rows = await db.query('st_character_index', orderBy: 'name ASC');
    return rows.map(STCharacterIndexRecord.fromMap).toList();
  }
}
