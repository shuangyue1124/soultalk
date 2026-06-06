import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/services/st_compat/character/st_character_repository.dart';
import 'package:soultalk/services/st_compat/chat/st_chat_repository.dart';
import 'package:soultalk/services/st_compat/presets/st_preset_models.dart';
import 'package:soultalk/services/st_compat/presets/st_preset_repository.dart';
import 'package:soultalk/services/st_compat/world_info/st_world_info_repository.dart';

void main() {
  late Directory root;
  late AppPaths paths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('st_repo_test_');
    paths = AppPaths.fromRootForTesting(root);
    await paths.ensureInitialized();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('reads character cards from compat character directory', () async {
    await File('${paths.characters.path}/Alice.json').writeAsString(
      jsonEncode({
        'spec': 'chara_card_v2',
        'data': {'name': 'Alice'},
      }),
    );

    final cards = await STCharacterRepository(paths: paths).getAll();

    expect(cards.single.name, 'Alice');
  });

  test('reads chat jsonl by character name', () async {
    final chatDir = Directory('${paths.chats.path}/Alice');
    await chatDir.create(recursive: true);
    await File(
      '${chatDir.path}/Alice - today.jsonl',
    ).writeAsString(jsonEncode({'name': 'Alice', 'mes': 'Hi'}));

    final files = await STChatRepository(paths: paths).listChatFiles('Alice');
    final chat = await STChatRepository(paths: paths).readFile(files.single);

    expect(chat.messages.single.mes, 'Hi');
  });

  test('reads world info by name', () async {
    await File('${paths.worlds.path}/World.json').writeAsString(
      jsonEncode({
        'entries': {
          '1': {
            'uid': 1,
            'key': ['city'],
            'content': 'Lore',
          },
        },
      }),
    );

    final repo = STWorldInfoRepository(paths: paths);
    final names = await repo.listNames();
    final world = await repo.readByName('World');

    expect(names, ['World']);
    expect(world.entries['1']!.content, 'Lore');
  });

  test('reads presets by api id', () async {
    await File(
      '${paths.settings.path}/OpenAI Settings/Default.json',
    ).writeAsString(
      jsonEncode({'chat_completion_source': 'claude', 'temperature': 1}),
    );

    final presets = await STPresetRepository(
      paths: paths,
    ).listByApiId('openai');

    expect(presets.single, isA<STOpenAIPreset>());
    expect(presets.single.name, 'Default');
  });
}
