import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/message.dart';
import 'database_service.dart';

class MessageDao {
  final DatabaseService _db;
  final _uuid = const Uuid();

  MessageDao(this._db);

  Future<Database> get _database => _db.database;

  Map<String, dynamic> _toMap(Message msg) => {
    'id': msg.id,
    'contact_id': msg.contactId,
    'role': msg.role.name,
    'content': msg.content,
    'type': msg.type.name,
    'is_streaming': msg.isStreaming ? 1 : 0,
    'token_count': msg.tokenCount,
    'metadata': msg.metadata != null ? jsonEncode(msg.metadata) : null,
    'created_at': msg.createdAt?.toIso8601String(),
  };

  Message _fromMap(Map<String, dynamic> map) => Message(
    id: map['id'] as String,
    contactId: map['contact_id'] as String,
    role: MessageRole.values.firstWhere(
      (r) => r.name == map['role'],
      orElse: () => MessageRole.user,
    ),
    content: map['content'] as String,
    type: MessageType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => MessageType.text,
    ),
    isStreaming: (map['is_streaming'] as int? ?? 0) == 1,
    tokenCount: map['token_count'] as int? ?? 0,
    metadata: map['metadata'] != null
        ? (jsonDecode(map['metadata'] as String) as Map<String, dynamic>)
        : null,
    createdAt: map['created_at'] != null
        ? DateTime.tryParse(map['created_at'] as String)
        : null,
  );

  Future<List<Message>> getByContact(
    String contactId, {
    int? limit,
    int? offset,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_fromMap).toList();
  }

  /// 获取最近 N 条消息（用于上下文管理）
  Future<List<Message>> getRecentByContact(String contactId, int n) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'contact_id = ? AND role != ?',
      whereArgs: [contactId, MessageRole.system.name],
      orderBy: 'created_at DESC',
      limit: n,
    );
    return rows.reversed.map(_fromMap).toList();
  }

  Future<List<Message>> getPageByContact(
    String contactId, {
    required int limit,
    required int offset,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.reversed.map(_fromMap).toList();
  }

  Future<Message> insert(Message message) async {
    final db = await _database;
    final now = DateTime.now();
    final newMsg = message.copyWith(
      id: message.id.isEmpty ? _uuid.v4() : message.id,
      createdAt: now,
    );
    await db.insert('messages', _toMap(newMsg));
    return newMsg;
  }

  /// 更新消息内容（用于流式更新）
  Future<void> updateContent(
    String id,
    String content, {
    bool isStreaming = false,
    int tokenCount = 0,
  }) async {
    final db = await _database;
    await db.update(
      'messages',
      {
        'content': content,
        'is_streaming': isStreaming ? 1 : 0,
        'token_count': tokenCount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateType(String id, String type) async {
    final db = await _database;
    await db.update(
      'messages',
      {'type': type},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTypeAndContent(
    String id,
    String type,
    String content,
  ) async {
    final db = await _database;
    await db.update(
      'messages',
      {'type': type, 'content': content},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMetadata(String id, String metadataJson) async {
    final db = await _database;
    await db.update(
      'messages',
      {'metadata': metadataJson},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByContact(String contactId) async {
    final db = await _database;
    await db.delete(
      'messages',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
  }

  Future<int> countByContact(String contactId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE contact_id = ?',
      [contactId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
