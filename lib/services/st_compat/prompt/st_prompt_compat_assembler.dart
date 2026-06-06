import '../character/st_character_models.dart';
import '../macros/macro_service.dart';
import '../presets/st_preset_models.dart';
import '../world_info/st_world_info_models.dart';

class STPromptAssemblyInput {
  final STCharacterCard character;
  final STContextPreset? contextPreset;
  final List<STWorldInfoEntry> worldInfoEntries;
  final String userName;
  final String persona;
  final String system;

  const STPromptAssemblyInput({
    required this.character,
    required this.contextPreset,
    required this.worldInfoEntries,
    required this.userName,
    this.persona = '',
    this.system = '',
  });
}

class STPromptAssemblyResult {
  final String systemPrompt;
  final String wiBefore;
  final String wiAfter;
  final String storyString;

  const STPromptAssemblyResult({
    required this.systemPrompt,
    required this.wiBefore,
    required this.wiAfter,
    required this.storyString,
  });
}

class STPromptCompatAssembler {
  final MacroService macroService;

  STPromptCompatAssembler({MacroService? macroService})
    : macroService = macroService ?? MacroService();

  STPromptAssemblyResult assemble(STPromptAssemblyInput input) {
    final wiBefore = _worldInfoForPosition(input.worldInfoEntries, 0);
    final wiAfter = _worldInfoForPosition(input.worldInfoEntries, 1);
    final systemPrompt = input.character.data.systemPrompt.isNotEmpty
        ? input.character.data.systemPrompt
        : input.system;

    final context = MacroContext({
      'char': input.character.name,
      'user': input.userName,
      'description': input.character.data.description,
      'personality': input.character.data.personality,
      'scenario': input.character.data.scenario,
      'system': systemPrompt,
      'persona': input.persona,
      'wiBefore': wiBefore,
      'wiAfter': wiAfter,
      'mesExamples': input.character.data.mesExample,
      'mesExamplesRaw': input.character.data.mesExample,
    });

    final storyTemplate =
        input.contextPreset?.storyString ?? _defaultStoryString;
    final storyString = macroService.render(storyTemplate, context).trim();

    return STPromptAssemblyResult(
      systemPrompt: macroService.render(systemPrompt, context),
      wiBefore: macroService.render(wiBefore, context),
      wiAfter: macroService.render(wiAfter, context),
      storyString: storyString,
    );
  }

  String _worldInfoForPosition(List<STWorldInfoEntry> entries, int position) {
    return entries
        .where((entry) => entry.position == position)
        .map((entry) => entry.content)
        .where((content) => content.trim().isNotEmpty)
        .join('\n');
  }

  static const _defaultStoryString = '''{{#if system}}{{system}}
{{/if}}{{#if wiBefore}}{{wiBefore}}
{{/if}}{{#if description}}{{description}}
{{/if}}{{#if personality}}{{char}}'s personality: {{personality}}
{{/if}}{{#if scenario}}Scenario: {{scenario}}
{{/if}}{{#if wiAfter}}{{wiAfter}}
{{/if}}{{#if persona}}{{persona}}
{{/if}}''';
}
