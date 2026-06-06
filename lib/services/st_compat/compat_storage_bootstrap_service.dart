import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/file_store/compat_file_store.dart';
import '../../core/file_store/file_manifest_service.dart';
import '../database/database_service.dart';
import '../database/file_index_dao.dart';
import '../database/st_character_index_dao.dart';
import '../database/st_chat_index_dao.dart';
import '../database/st_preset_index_dao.dart';
import '../database/st_world_index_dao.dart';
import 'character/st_character_card_parser.dart';
import 'chat/st_chat_jsonl_codec.dart';
import 'presets/st_preset_parser.dart';
import 'world_info/st_world_info_parser.dart';

class CompatStorageBootstrapService {
  final AppPaths paths;
  final CompatFileStore fileStore;
  final FileManifestService manifestService;
  final FileIndexDao fileIndexDao;
  final STCharacterIndexDao characterIndexDao;
  final STChatIndexDao chatIndexDao;
  final STWorldIndexDao worldIndexDao;
  final STPresetIndexDao presetIndexDao;
  final STCharacterCardParser characterParser;
  final STChatJsonlCodec chatCodec;
  final STWorldInfoParser worldParser;
  final STPresetParser presetParser;

  CompatStorageBootstrapService({
    required this.paths,
    required this.fileStore,
    required this.manifestService,
    required this.fileIndexDao,
    required this.characterIndexDao,
    required this.chatIndexDao,
    required this.worldIndexDao,
    required this.presetIndexDao,
    STCharacterCardParser? characterParser,
    STChatJsonlCodec? chatCodec,
    STWorldInfoParser? worldParser,
    STPresetParser? presetParser,
  }) : characterParser = characterParser ?? const STCharacterCardParser(),
       chatCodec = chatCodec ?? STChatJsonlCodec(),
       worldParser = worldParser ?? STWorldInfoParser(),
       presetParser = presetParser ?? STPresetParser();

  static Future<CompatStorageBootstrapService> create() async {
    final paths = await AppPaths.create();
    final db = DatabaseService();
    return CompatStorageBootstrapService(
      paths: paths,
      fileStore: CompatFileStore(paths: paths),
      manifestService: FileManifestService(),
      fileIndexDao: FileIndexDao(db),
      characterIndexDao: STCharacterIndexDao(db),
      chatIndexDao: STChatIndexDao(db),
      worldIndexDao: STWorldIndexDao(db),
      presetIndexDao: STPresetIndexDao(db),
    );
  }

  Future<void> initializeAndRebuildIndex() async {
    await fileStore.initialize();
    final entries = await manifestService.scan(paths.stCompat);
    await fileIndexDao.replaceActiveSet(
      entries.map(FileIndexRecord.fromManifest).toList(),
    );
    await characterIndexDao.replaceAll(await _buildCharacterIndex());
    await chatIndexDao.replaceAll(await _buildChatIndex());
    await worldIndexDao.replaceAll(await _buildWorldIndex());
    await presetIndexDao.replaceAll(await _buildPresetIndex());
  }

  Future<List<STCharacterIndexRecord>> _buildCharacterIndex() async {
    final records = <STCharacterIndexRecord>[];
    if (!await paths.characters.exists()) return records;

    await for (final entity in paths.characters.list(recursive: false)) {
      if (entity is! File) continue;
      final extension = p.extension(entity.path).toLowerCase();
      if (extension != '.json' && extension != '.png') continue;
      try {
        final card = extension == '.png'
            ? characterParser.parsePngBytes(await entity.readAsBytes())
            : characterParser.parseJsonString(await entity.readAsString());
        final relative = _relativeToCompat(entity);
        records.add(
          STCharacterIndexRecord(
            characterId: _stableId(relative),
            name: card.name,
            filePath: relative,
            spec: card.spec,
            specVersion: card.specVersion,
            avatarPath: card.raw['avatar'] as String?,
            tags: jsonEncode(card.data.tags),
            creator: card.raw['creator'] as String?,
            characterVersion: card.raw['character_version'] as String?,
            favorite: (card.data.extensions['fav'] as bool?) ?? false,
            pinned: false,
            unreadCount: 0,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to index character file ${entity.path}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return records;
  }

  Future<List<STChatIndexRecord>> _buildChatIndex() async {
    final records = <STChatIndexRecord>[];
    if (!await paths.chats.exists()) return records;

    await for (final entity in paths.chats.list(recursive: true)) {
      if (entity is! File ||
          p.extension(entity.path).toLowerCase() != '.jsonl') {
        continue;
      }
      try {
        final chat = chatCodec.parseString(await entity.readAsString());
        final relative = _relativeToCompat(entity);
        final characterName = chat.metadata?.characterName.isNotEmpty == true
            ? chat.metadata!.characterName
            : p.basename(p.dirname(entity.path));
        final lastMessage = chat.messages.isEmpty ? null : chat.messages.last;
        records.add(
          STChatIndexRecord(
            chatId: _stableId(relative),
            characterId: null,
            characterName: characterName,
            filePath: relative,
            title: p.basenameWithoutExtension(entity.path),
            messageCount: chat.messages.length,
            lastMessagePreview: lastMessage?.mes,
            lastMessageAt: _parseDateMillis(lastMessage?.sendDate),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to index chat file ${entity.path}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return records;
  }

  Future<List<STWorldIndexRecord>> _buildWorldIndex() async {
    final records = <STWorldIndexRecord>[];
    if (!await paths.worlds.exists()) return records;

    await for (final entity in paths.worlds.list(recursive: false)) {
      if (entity is! File ||
          p.extension(entity.path).toLowerCase() != '.json') {
        continue;
      }
      try {
        final world = worldParser.parseJsonString(await entity.readAsString());
        final relative = _relativeToCompat(entity);
        final name = p.basenameWithoutExtension(entity.path);
        records.add(
          STWorldIndexRecord(
            worldId: _stableId(relative),
            name: name,
            filePath: relative,
            entryCount: world.entries.length,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to index world info file ${entity.path}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return records;
  }

  Future<List<STPresetIndexRecord>> _buildPresetIndex() async {
    final records = <STPresetIndexRecord>[];
    if (!await paths.settings.exists()) return records;

    await for (final entity in paths.settings.list(recursive: true)) {
      if (entity is! File ||
          p.extension(entity.path).toLowerCase() != '.json') {
        continue;
      }
      try {
        final apiId = _apiIdForPresetFile(entity);
        final name = p.basenameWithoutExtension(entity.path);
        presetParser.parseJsonString(
          apiId: apiId,
          name: name,
          contents: await entity.readAsString(),
        );
        final relative = _relativeToCompat(entity);
        records.add(
          STPresetIndexRecord(
            presetId: _stableId(relative),
            apiId: apiId,
            name: name,
            filePath: relative,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to index preset file ${entity.path}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    return records;
  }

  String _relativeToCompat(File file) {
    return p
        .relative(file.path, from: paths.stCompat.path)
        .split(p.separator)
        .join('/');
  }

  String _stableId(String value) => base64Url.encode(utf8.encode(value));

  int? _parseDateMillis(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.millisecondsSinceEpoch;
  }

  String _apiIdForPresetFile(File file) {
    final relative = _relativeToCompat(file);
    final parts = relative.split('/');
    final directory = parts.first == 'settings' && parts.length > 1
        ? parts[1]
        : parts.first;
    return switch (directory) {
      'KoboldAI Settings' => 'kobold',
      'NovelAI Settings' => 'novel',
      'OpenAI Settings' => 'openai',
      'TextGen Settings' => 'textgenerationwebui',
      'instruct' => 'instruct',
      'context' => 'context',
      'sysprompt' => 'sysprompt',
      'reasoning' => 'reasoning',
      _ => directory,
    };
  }
}
