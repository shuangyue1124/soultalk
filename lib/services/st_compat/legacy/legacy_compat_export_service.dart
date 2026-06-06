import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/app_paths.dart';
import '../../../core/file_store/atomic_file_writer.dart';
import '../../../core/file_store/path_sanitizer.dart';
import '../../database/database_service.dart';
import '../compat_storage_bootstrap_service.dart';

class LegacyCompatExportService {
  final AppPaths paths;
  final DatabaseService databaseService;
  final CompatStorageBootstrapService bootstrapService;
  final AtomicFileWriter atomicFileWriter;
  final PathSanitizer pathSanitizer;

  LegacyCompatExportService({
    required this.paths,
    required this.databaseService,
    required this.bootstrapService,
    AtomicFileWriter? atomicFileWriter,
    PathSanitizer? pathSanitizer,
  }) : atomicFileWriter = atomicFileWriter ?? AtomicFileWriter(),
       pathSanitizer = pathSanitizer ?? PathSanitizer();

  Future<LegacyCompatExportResult> exportAndRebuildIndex() async {
    final characters = await exportContactsToCharacters();
    final chats = await exportMessagesToChats();
    await bootstrapService.initializeAndRebuildIndex();
    return LegacyCompatExportResult(characters: characters, chats: chats);
  }

  Future<int> exportContactsToCharacters() async {
    final db = await databaseService.database;
    final contacts = await db.query('contacts');
    var exported = 0;

    for (final contact in contacts) {
      final id = contact['id'] as String? ?? '';
      final name = contact['name'] as String? ?? id;
      if (name.isEmpty) continue;

      final file = await _nextAvailableFile(
        paths.characters,
        pathSanitizer.fileName(name),
        '.json',
      );
      if (file == null) continue;

      final characterCardJson = contact['character_card_json'] as String?;
      final payload = _contactToCharacterJson(contact, characterCardJson);
      await atomicFileWriter.writeAsString(
        file,
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      exported++;
    }

    return exported;
  }

  Future<int> exportMessagesToChats() async {
    final db = await databaseService.database;
    final contacts = await db.query('contacts');
    var exported = 0;

    for (final contact in contacts) {
      final contactId = contact['id'] as String?;
      final characterName = contact['name'] as String? ?? contactId ?? '';
      if (contactId == null || characterName.isEmpty) continue;

      final messages = await db.query(
        'messages',
        where: 'contact_id = ?',
        whereArgs: [contactId],
        orderBy: 'created_at ASC',
      );
      if (messages.isEmpty) continue;

      final characterDir = Directory(
        p.join(paths.chats.path, pathSanitizer.fileName(characterName)),
      );
      final file = await _nextAvailableFile(
        characterDir,
        '${pathSanitizer.fileName(characterName)} - imported',
        '.jsonl',
      );
      if (file == null) continue;

      final lines = <String>[
        jsonEncode(_chatMetadata(contact, messages)),
        ...messages.map(
          (message) => jsonEncode(_messageToJsonl(message, contact)),
        ),
      ];
      await atomicFileWriter.writeAsString(file, lines.join('\n'));
      exported++;
    }

    return exported;
  }

  Map<String, dynamic> _contactToCharacterJson(
    Map<String, Object?> contact,
    String? characterCardJson,
  ) {
    if (characterCardJson != null && characterCardJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(characterCardJson);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    final name = contact['name'] as String? ?? '';
    final description = contact['description'] as String? ?? '';
    final systemPrompt = contact['system_prompt'] as String? ?? '';
    final tags = _decodeStringList(contact['tags'] as String?);

    return {
      'spec': 'chara_card_v2',
      'spec_version': '2.0',
      'name': name,
      'description': description,
      'personality': '',
      'scenario': '',
      'first_mes': '',
      'mes_example': '',
      'avatar': contact['avatar'],
      'tags': tags,
      'data': {
        'name': name,
        'description': description,
        'personality': '',
        'scenario': '',
        'first_mes': '',
        'mes_example': '',
        'system_prompt': systemPrompt,
        'post_history_instructions': '',
        'tags': tags,
        'extensions': {
          'soultalk': {
            'contact_id': contact['id'],
            'api_config_id': contact['api_config_id'],
          },
        },
      },
    };
  }

  Map<String, dynamic> _chatMetadata(
    Map<String, Object?> contact,
    List<Map<String, Object?>> messages,
  ) {
    return {
      'user_name': 'User',
      'character_name': contact['name'] as String? ?? '',
      'create_date':
          messages.first['created_at'] as String? ??
          DateTime.now().toIso8601String(),
      'chat_metadata': {
        'chat_id_hash': contact['id'].hashCode,
        'extensions': {
          'soultalk': {
            'contact_id': contact['id'],
            'imported_from_sqlite': true,
          },
        },
      },
    };
  }

  Map<String, dynamic> _messageToJsonl(
    Map<String, Object?> message,
    Map<String, Object?> contact,
  ) {
    final role = message['role'] as String? ?? '';
    final metadata = message['metadata'] as String?;
    return {
      'name': role == 'user' ? 'User' : contact['name'] as String? ?? '',
      'is_user': role == 'user',
      'is_system': role == 'system',
      'send_date': message['created_at'] as String? ?? '',
      'mes': message['content'] as String? ?? '',
      'extra': {
        'soultalk': {
          'message_id': message['id'],
          'type': message['type'],
          'token_count': message['token_count'],
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
      },
    };
  }

  Future<File?> _nextAvailableFile(
    Directory directory,
    String baseName,
    String extension,
  ) async {
    await directory.create(recursive: true);
    for (var i = 0; i < 1000; i++) {
      final suffix = i == 0 ? '' : '.imported-$i';
      final file = File(p.join(directory.path, '$baseName$suffix$extension'));
      if (!await file.exists()) return file;
    }
    return null;
  }

  List<String> _decodeStringList(String? jsonText) {
    if (jsonText == null || jsonText.isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }
}

class LegacyCompatExportResult {
  final int characters;
  final int chats;

  const LegacyCompatExportResult({
    required this.characters,
    required this.chats,
  });
}
