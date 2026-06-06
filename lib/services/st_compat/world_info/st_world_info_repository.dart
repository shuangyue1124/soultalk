import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/app_paths.dart';
import 'st_world_info_models.dart';
import 'st_world_info_parser.dart';

class STWorldInfoRepository {
  final AppPaths paths;
  final STWorldInfoParser parser;

  STWorldInfoRepository({required this.paths, STWorldInfoParser? parser})
    : parser = parser ?? STWorldInfoParser();

  Future<List<String>> listNames() async {
    final directory = paths.worlds;
    if (!await directory.exists()) return const [];

    final names = <String>[];
    await for (final entity in directory.list(recursive: false)) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.json') {
        names.add(p.basenameWithoutExtension(entity.path));
      }
    }
    names.sort();
    return names;
  }

  Future<STWorldInfoLorebook> readByName(String name) async {
    final file = File(p.join(paths.worlds.path, '$name.json'));
    return parser.parseJsonString(await file.readAsString());
  }
}
