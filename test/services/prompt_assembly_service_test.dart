import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/models/contact.dart';
import 'package:soultalk/models/message.dart';
import 'package:soultalk/models/prompt_system.dart';
import 'package:soultalk/services/api/prompt_assembly_service.dart';

void main() {
  group('PromptAssemblyService', () {
    test(
      'assembles post-history instructions and enabled after-history prompts',
      () async {
        SharedPreferences.setMockInitialValues({
          'global_prompt_enabled': false,
          'prompt_preset': jsonEncode(
            PromptPreset(
              id: 'preset',
              name: 'Preset',
              postHistoryInstructions: 'reply briefly',
              customPrompts: const [
                PromptEntry(
                  id: 'after',
                  name: 'After history',
                  content: 'stay in character',
                  position: PromptInjectionPosition.afterHistory,
                  priority: 1,
                ),
                PromptEntry(
                  id: 'disabled',
                  name: 'Disabled',
                  content: 'do not include',
                  enabled: false,
                  position: PromptInjectionPosition.afterHistory,
                ),
              ],
            ).toJson(),
          ),
        });

        final assembled = await PromptAssemblyService().assemble(
          contact: const Contact(id: 'c1', name: 'Alice'),
          history: const [
            Message(
              id: 'm1',
              contactId: 'c1',
              role: MessageRole.user,
              content: 'hello',
            ),
          ],
        );

        expect(assembled.postHistoryPrompt, contains('reply briefly'));
        expect(assembled.postHistoryPrompt, contains('stay in character'));
        expect(assembled.postHistoryPrompt, isNot(contains('do not include')));
      },
    );
  });
}
