import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/presets/st_preset_models.dart';
import 'package:soultalk/services/st_compat/presets/st_preset_parser.dart';

void main() {
  test('parses openai preset prompts and keeps raw fields', () {
    final preset =
        STPresetParser().parseJsonString(
              apiId: 'openai',
              name: 'Default',
              contents: jsonEncode({
                'chat_completion_source': 'claude',
                'claude_model': 'claude-sonnet-4-6',
                'temperature': 0.8,
                'openai_max_context': 120000,
                'openai_max_tokens': 4096,
                'stream_openai': true,
                'prompts': [
                  {
                    'identifier': 'main',
                    'name': 'Main Prompt',
                    'system_prompt': true,
                    'role': 'system',
                    'content': 'Hello {{char}}',
                  },
                ],
                'unknown': 'kept',
              }),
            )
            as STOpenAIPreset;

    expect(preset.chatCompletionSource, 'claude');
    expect(preset.temperature, 0.8);
    expect(preset.prompts.single.identifier, 'main');
    expect(preset.raw['unknown'], 'kept');
  });

  test('parses context preset', () {
    final preset =
        STPresetParser().parseJsonString(
              apiId: 'context',
              name: 'ChatML',
              contents: jsonEncode({
                'name': 'ChatML',
                'story_string': '{{system}}',
                'example_separator': '<START>',
                'chat_start': '<chat>',
              }),
            )
            as STContextPreset;

    expect(preset.storyString, '{{system}}');
  });
}
