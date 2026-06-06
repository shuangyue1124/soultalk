import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/app_paths.dart';
import 'st_character_card_parser.dart';
import 'st_character_models.dart';

class STCharacterRepository {
  final AppPaths paths;
  final STCharacterCardParser parser;

  STCharacterRepository({required this.paths, STCharacterCardParser? parser})
    : parser = parser ?? const STCharacterCardParser();

  Future<List<STCharacterCard>> getAll() async {
    final files = await _characterFiles();
    final cards = <STCharacterCard>[];
    for (final file in files) {
      try {
        cards.add(await readFile(file));
      } on FormatException {
        continue;
      }
    }
    return cards;
  }

  Future<STCharacterCard> readFile(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (extension == '.png') {
      return parser.parsePngBytes(await file.readAsBytes());
    }
    if (extension == '.json') {
      return parser.parseJsonString(await file.readAsString());
    }
    throw const FormatException('Unsupported character card file type.');
  }

  Future<List<File>> _characterFiles() async {
    final directory = paths.characters;
    if (!await directory.exists()) return const [];

    final files = <File>[];
    await for (final entity in directory.list(recursive: false)) {
      if (entity is! File) continue;
      final extension = p.extension(entity.path).toLowerCase();
      if (extension == '.png' || extension == '.json') files.add(entity);
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
