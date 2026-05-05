import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/contact.dart';
import 'database_service.dart';

class ContactDao {
  final DatabaseService _db;
  final _uuid = const Uuid();

  ContactDao(this._db);

  Future<Database> get _database => _db.database;

  Map<String, dynamic> _toMap(Contact contact) => {
    'id': contact.id,
    'name': contact.name,
    'avatar': contact.avatar,
    'description': contact.description,
    'api_config_id': contact.apiConfigId,
    'system_prompt': contact.systemPrompt,
    'character_card_json': contact.characterCardJson,
    'tags': jsonEncode(contact.tags),
    'pinned': contact.pinned ? 1 : 0,
    'unread_count': contact.unreadCount,
    'last_message': contact.lastMessage,
    'last_message_at': contact.lastMessageAt?.toIso8601String(),
    'proactive_enabled': contact.proactiveEnabled ? 1 : 0,
    'last_proactive_at': contact.lastProactiveAt?.toIso8601String(),
    'created_at': contact.createdAt?.toIso8601String(),
    'updated_at': contact.updatedAt?.toIso8601String(),
  };

  Contact _fromMap(Map<String, dynamic> map) => Contact(
    id: map['id'] as String,
    name: map['name'] as String,
    avatar: map['avatar'] as String?,
    description: map['description'] as String? ?? '',
    apiConfigId: map['api_config_id'] as String?,
    systemPrompt: map['system_prompt'] as String? ?? '',
    characterCardJson: map['character_card_json'] as String?,
    tags: List<String>.from(jsonDecode(map['tags'] as String? ?? '[]') as List),
    pinned: (map['pinned'] as int? ?? 0) == 1,
    unreadCount: map['unread_count'] as int? ?? 0,
    lastMessage: map['last_message'] as String?,
    lastMessageAt: map['last_message_at'] != null
        ? DateTime.tryParse(map['last_message_at'] as String)
        : null,
    proactiveEnabled: (map['proactive_enabled'] as int? ?? 1) == 1,
    lastProactiveAt: map['last_proactive_at'] != null
        ? DateTime.tryParse(map['last_proactive_at'] as String)
        : null,
    createdAt: map['created_at'] != null
        ? DateTime.tryParse(map['created_at'] as String)
        : null,
    updatedAt: map['updated_at'] != null
        ? DateTime.tryParse(map['updated_at'] as String)
        : null,
  );

  Future<List<Contact>> getAll() async {
    final db = await _database;
    final rows = await db.query(
      'contacts',
      orderBy: 'pinned DESC, last_message_at DESC, created_at ASC',
    );
    return rows.map(_fromMap).toList();
  }

  Future<Contact?> getById(String id) async {
    final db = await _database;
    final rows = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  Future<List<Contact>> search(String query) async {
    final db = await _database;
    final rows = await db.query(
      'contacts',
      where: 'name LIKE ? OR description LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'pinned DESC, name ASC',
    );
    return rows.map(_fromMap).toList();
  }

  Future<Contact> insert(Contact contact) async {
    final db = await _database;
    final now = DateTime.now();
    final newContact = contact.copyWith(
      id: contact.id.isEmpty ? _uuid.v4() : contact.id,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('contacts', _toMap(newContact));
    return newContact;
  }

  Future<void> update(Contact contact) async {
    final db = await _database;
    final updated = contact.copyWith(updatedAt: DateTime.now());
    await db.update(
      'contacts',
      _toMap(updated),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> updateLastMessage(
    String contactId,
    String message,
    DateTime at,
  ) async {
    final db = await _database;
    await db.update(
      'contacts',
      {
        'last_message': message,
        'last_message_at': at.toIso8601String(),
        'updated_at': at.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  Future<void> incrementUnread(String contactId) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE contacts SET unread_count = unread_count + 1 WHERE id = ?',
      [contactId],
    );
  }

  Future<void> clearUnread(String contactId) async {
    final db = await _database;
    await db.update(
      'contacts',
      {'unread_count': 0},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }
}
