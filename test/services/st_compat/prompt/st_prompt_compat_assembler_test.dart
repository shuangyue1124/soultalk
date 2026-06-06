import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/character/st_character_models.dart';
import 'package:soultalk/services/st_compat/presets/st_preset_models.dart';
import 'package:soultalk/services/st_compat/prompt/st_prompt_compat_assembler.dart';
import 'package:soultalk/services/st_compat/world_info/st_world_info_models.dart';

void main() {
  test('assembles story string from context preset macros', () {
    final result = STPromptCompatAssembler().assemble(
      STPromptAssemblyInput(
        character: _character(),
        userName: 'Bob',
        contextPreset: const STContextPreset(
          apiId: 'context',
          name: 'Test',
          raw: {},
          storyString:
              '{{system}}\n{{description}}\n{{wiBefore}}\n{{char}}/{{user}}',
          exampleSeparator: '',
          chatStart: '',
        ),
        worldInfoEntries: [_worldInfo(position: 0, content: 'World before')],
      ),
    );

    expect(result.storyString, contains('Stay in character'));
    expect(result.storyString, contains('A friendly character'));
    expect(result.storyString, contains('World before'));
    expect(result.storyString, contains('Alice/Bob'));
  });

  test('splits world info by position', () {
    final result = STPromptCompatAssembler().assemble(
      STPromptAssemblyInput(
        character: _character(),
        userName: 'Bob',
        contextPreset: null,
        worldInfoEntries: [
          _worldInfo(position: 0, content: 'Before'),
          _worldInfo(position: 1, content: 'After'),
        ],
      ),
    );

    expect(result.wiBefore, 'Before');
    expect(result.wiAfter, 'After');
    expect(result.storyString, contains('Before'));
    expect(result.storyString, contains('After'));
  });
}

STCharacterCard _character() {
  return const STCharacterCard(
    spec: 'chara_card_v2',
    specVersion: '2.0',
    name: 'Alice',
    raw: {},
    data: STCharacterData(
      name: 'Alice',
      description: 'A friendly character',
      personality: 'Warm',
      scenario: 'Cafe',
      firstMes: 'Hello',
      mesExample: '<START>',
      systemPrompt: 'Stay in character',
      postHistoryInstructions: '',
      tags: [],
      alternateGreetings: [],
      groupOnlyGreetings: [],
      extensions: {},
      characterBook: null,
    ),
  );
}

STWorldInfoEntry _worldInfo({required int position, required String content}) {
  return STWorldInfoEntry(
    uid: position,
    key: const [],
    keySecondary: const [],
    comment: '',
    content: content,
    constant: true,
    selective: false,
    order: 0,
    position: position,
    disable: false,
    displayIndex: 0,
    addMemo: false,
    group: '',
    groupOverride: false,
    groupWeight: 0,
    sticky: 0,
    cooldown: 0,
    delay: 0,
    probability: 100,
    depth: 4,
    useProbability: false,
    role: null,
    vectorized: false,
    excludeRecursion: false,
    preventRecursion: false,
    delayUntilRecursion: false,
    scanDepth: null,
    caseSensitive: null,
    matchWholeWords: null,
    useGroupScoring: null,
    automationId: '',
    raw: const {},
  );
}
