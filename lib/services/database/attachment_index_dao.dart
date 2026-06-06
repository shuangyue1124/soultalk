import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class AttachmentIndexRecord {
  final String id;
  final String chatId;
  final String? messageId;
  final String originalName;
  final String? mimeType;
  final String relativePath;
  final String sha256;
  final int size;
  final int createdAt;

  const AttachmentIndexRecord({
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.originalName,
    required this.mimeType,
    required this.relativePath,
    required this.sha256,
    required this.size,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'chat_id': chatId,
    'message_id': messageId,
    'original_name': originalName,
    'mime_type': mimeType,
    'relative_path': relativePath,
    'sha256': sha256,
    'size': size,
    'created_at': createdAt,
  };

  factory AttachmentIndexRecord.fromMap(Map<String, Object?> map) {
    return AttachmentIndexRecord(
      id: map['id']! as String,
      chatId: map['chat_id']! as String,
      messageId: map['message_id'] as String?,
      originalName: map['original_name']! as String,
      mimeType: map['mime_type'] as String?,
      relativePath: map['relative_path']! as String,
      sha256: map['sha256']! as String,
      size: map['size']! as int,
      createdAt: map['created_at']! as int,
    );
  }
}

class AttachmentIndexDao {
  final DatabaseService _db;

  AttachmentIndexDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> upsert(AttachmentIndexRecord record) async {
    final db = await _database;
    await db.insert(
      'attachment_index',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AttachmentIndexRecord?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      'attachment_index',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttachmentIndexRecord.fromMap(rows.first);
  }

  Future<void> updateMessageId(String id, String messageId) async {
    final db = await _database;
    await db.update(
      'attachment_index',
      {'message_id': messageId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
