import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/app_paths.dart';
import 'st_preset_models.dart';
import 'st_preset_parser.dart';

class STPresetRepository {
  final AppPaths paths;
  final STPresetParser parser;

  STPresetRepository({required this.paths, STPresetParser? parser})
    : parser = parser ?? STPresetParser();

  Future<List<STPreset>> listByApiId(String apiId) async {
    final directory = Directory(
      p.join(paths.settings.path, _directoryFor(apiId)),
    );
    if (!await directory.exists()) return const [];

    final presets = <STPreset>[];
    await for (final entity in directory.list(recursive: false)) {
      if (entity is! File ||
          p.extension(entity.path).toLowerCase() != '.json') {
        continue;
      }
      try {
        presets.add(
          parser.parseJsonString(
            apiId: apiId,
            name: p.basenameWithoutExtension(entity.path),
            contents: await entity.readAsString(),
          ),
        );
      } on FormatException {
        continue;
      }
    }
    presets.sort((a, b) => a.name.compareTo(b.name));
    return presets;
  }

  Future<STPreset> read({required String apiId, required String name}) async {
    final file = File(
      p.join(paths.settings.path, _directoryFor(apiId), '$name.json'),
    );
    return parser.parseJsonString(
      apiId: apiId,
      name: name,
      contents: await file.readAsString(),
    );
  }

  String _directoryFor(String apiId) {
    return switch (apiId) {
      'kobold' => 'KoboldAI Settings',
      'novel' => 'NovelAI Settings',
      'openai' => 'OpenAI Settings',
      'textgenerationwebui' => 'TextGen Settings',
      'instruct' => 'instruct',
      'context' => 'context',
      'sysprompt' => 'sysprompt',
      'reasoning' => 'reasoning',
      _ => apiId,
    };
  }
}
