import 'dart:io';

import '../../../core/app_paths.dart';
import 'st_chat_jsonl_codec.dart';
import 'st_chat_models.dart';

class STChatRepository {
  final AppPaths paths;
  final STChatJsonlCodec codec;

  STChatRepository({required this.paths, STChatJsonlCodec? codec})
    : codec = codec ?? STChatJsonlCodec();

  Future<List<File>> listChatFiles(String characterName) async {
    final directory = Directory('${paths.chats.path}/$characterName');
    if (!await directory.exists()) return const [];

    final files = <File>[];
    await for (final entity in directory.list(recursive: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.jsonl')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<STChatFile> readFile(File file) async {
    return codec.parseString(await file.readAsString());
  }
}
