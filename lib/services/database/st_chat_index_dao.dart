import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class STChatIndexRecord {
  final String chatId;
  final String? characterId;
  final String characterName;
  final String filePath;
  final String? title;
  final int messageCount;
  final String? lastMessagePreview;
  final int? lastMessageAt;
  final int updatedAt;

  const STChatIndexRecord({
    required this.chatId,
    required this.characterId,
    required this.characterName,
    required this.filePath,
    required this.title,
    required this.messageCount,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'chat_id': chatId,
    'character_id': characterId,
    'character_name': characterName,
    'file_path': filePath,
    'title': title,
    'message_count': messageCount,
    'last_message_preview': lastMessagePreview,
    'last_message_at': lastMessageAt,
    'updated_at': updatedAt,
  };

  factory STChatIndexRecord.fromMap(Map<String, Object?> map) {
    return STChatIndexRecord(
      chatId: map['chat_id']! as String,
      characterId: map['character_id'] as String?,
      characterName: map['character_name']! as String,
      filePath: map['file_path']! as String,
      title: map['title'] as String?,
      messageCount: map['message_count'] as int? ?? 0,
      lastMessagePreview: map['last_message_preview'] as String?,
      lastMessageAt: map['last_message_at'] as int?,
      updatedAt: map['updated_at']! as int,
    );
  }
}

class STChatIndexDao {
  final DatabaseService _db;

  STChatIndexDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> replaceAll(List<STChatIndexRecord> records) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('st_chat_index');
      for (final record in records) {
        await txn.insert('st_chat_index', record.toMap());
      }
    });
  }

  Future<List<STChatIndexRecord>> getAll() async {
    final db = await _database;
    final rows = await db.query(
      'st_chat_index',
      orderBy: 'last_message_at DESC',
    );
    return rows.map(STChatIndexRecord.fromMap).toList();
  }
}
