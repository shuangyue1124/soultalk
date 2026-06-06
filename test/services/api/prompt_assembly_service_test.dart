import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/models/contact.dart';
import 'package:soultalk/services/api/prompt_assembly_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'uses SillyTavern system and post history fields from character card',
    () async {
      final cardJson = jsonEncode({
        'spec': 'chara_card_v2',
        'data': {
          'name': 'Alice',
          'description': 'ST description',
          'personality': 'ST personality',
          'scenario': 'ST scenario',
          'system_prompt': 'ST system prompt for {{char}} and {{user}}',
          'post_history_instructions': 'ST post history instruction',
        },
      });

      final assembled = await PromptAssemblyService().assemble(
        contact: Contact(id: 'c1', name: 'Alice', characterCardJson: cardJson),
        history: const [],
        userName: 'Bob',
      );

      expect(assembled.systemPrompt, contains('ST description'));
      expect(assembled.systemPrompt, contains('ST personality'));
      expect(assembled.systemPrompt, contains('ST scenario'));
      expect(
        assembled.systemPrompt,
        contains('ST system prompt for Alice and Bob'),
      );
      expect(
        assembled.postHistoryPrompt,
        contains('ST post history instruction'),
      );
    },
  );

  test('applies character card regex scripts to ST prompt fields', () async {
    final cardJson = jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': 'Alice',
        'system_prompt': 'foo system',
        'post_history_instructions': 'foo instruction',
        'extensions': {
          'regex_scripts': [
            {
              'scriptName': 'Replace foo',
              'trigger': 'foo',
              'replace': 'bar',
              'opts': {
                'source': ['worldInfo'],
              },
            },
          ],
        },
      },
    });

    final assembled = await PromptAssemblyService().assemble(
      contact: Contact(id: 'c1', name: 'Alice', characterCardJson: cardJson),
      history: const [],
      userName: 'Bob',
    );

    expect(assembled.systemPrompt, contains('bar system'));
    expect(assembled.postHistoryPrompt, contains('bar instruction'));
  });
  test(
    'does not duplicate global prompt when preset main prompt is empty',
    () async {
      SharedPreferences.setMockInitialValues({
        'global_prompt_enabled': true,
        'global_prompt_text': 'global rule',
      });

      final assembled = await PromptAssemblyService().assemble(
        contact: const Contact(id: 'c1', name: 'Alice'),
        history: const [],
        userName: 'Bob',
      );

      expect('global rule'.allMatches(assembled.systemPrompt ?? '').length, 1);
    },
  );
}
