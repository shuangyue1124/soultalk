import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/character_card.dart';
import '../../models/prompt_system.dart';
import '../../models/regex_script.dart';
import '../regex/regex_service.dart';
import '../st_compat/character/st_character_card_parser.dart';
import '../st_compat/character/st_character_models.dart';
import '../st_compat/regex/st_regex_mapper.dart';
import '../st_compat/regex/st_regex_parser.dart';

class PromptAssemblyService {
  final _regexService = const RegexService();
  final _stCharacterParser = const STCharacterCardParser();
  final _stRegexParser = STRegexParser();
  final _stRegexMapper = STRegexMapper();

  Future<AssembledPrompt> assemble({
    required Contact contact,
    required List<Message> history,
    String? userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final promptPreset = await PromptPreset.load(prefs, 'prompt_preset');
    final worldInfoEntries = await _loadWorldInfo(prefs, contact.id);

    final userName_ = userName ?? prefs.getString('self_profile') ?? '用户';

    final characterCard = _parseCharacterCard(contact.characterCardJson);
    final stCharacterCard = _parseSTCharacterCard(contact.characterCardJson);

    final wiBeforeEntries = <WorldInfoEntry>[];
    final wiAfterEntries = <WorldInfoEntry>[];
    final allText = _buildAllText(contact, history, userName_);

    for (final wi in worldInfoEntries) {
      if (!wi.enabled) continue;
      if (wi.matchesKey(allText)) {
        if (wi.position <= 1) {
          wiBeforeEntries.add(wi);
        } else {
          wiAfterEntries.add(wi);
        }
      }
    }

    wiBeforeEntries.sort((a, b) => b.priority.compareTo(a.priority));
    wiAfterEntries.sort((a, b) => b.priority.compareTo(a.priority));

    final wiBeforeText = wiBeforeEntries.map((e) => e.content).join('\n');
    final wiAfterText = wiAfterEntries.map((e) => e.content).join('\n');

    final mainPrompt = _resolveMainPrompt(prefs, promptPreset);
    final secondaryPrompt = promptPreset.secondaryPrompt;
    final postHistoryInstructions = promptPreset.postHistoryInstructions;

    final description =
        stCharacterCard?.data.description ?? characterCard?.description ?? '';
    final personality =
        stCharacterCard?.data.personality ?? characterCard?.personality ?? '';
    final scenario =
        stCharacterCard?.data.scenario ?? characterCard?.scenario ?? '';
    final stSystemPrompt = stCharacterCard?.data.systemPrompt ?? '';
    final charSystemPrompt = contact.systemPrompt.isNotEmpty
        ? contact.systemPrompt
        : stSystemPrompt;

    final template = promptPreset.contextTemplate;
    final storyString = template.render({
      'system': mainPrompt,
      'wiBefore': wiBeforeText,
      'description': description.isNotEmpty
          ? '[Character Description]\n$description'
          : '',
      'personality': personality.isNotEmpty
          ? '[Personality]\n$personality'
          : '',
      'scenario': scenario.isNotEmpty ? '[Scenario]\n$scenario' : '',
      'wiAfter': wiAfterText,
      'charSystem': charSystemPrompt,
    });

    final parts = <String>[];

    if (storyString.isNotEmpty) parts.add(storyString);

    if (secondaryPrompt.isNotEmpty) parts.add(secondaryPrompt);

    final selfProfile = prefs.getString('self_profile') ?? '';
    if (selfProfile.isNotEmpty) {
      parts.add('关于对话对象（用户）的信息：$selfProfile');
    }

    if (charSystemPrompt.isNotEmpty &&
        !storyString.contains(charSystemPrompt)) {
      parts.add(charSystemPrompt);
    }

    var systemPrompt = parts.where((p) => p.isNotEmpty).join('\n\n');

    final stRegexScripts = _loadSTRegexScripts(stCharacterCard);
    if (stRegexScripts.isNotEmpty) {
      systemPrompt = _regexService.applyScripts(
        systemPrompt,
        stRegexScripts,
        RegexPlacement.worldInfo,
      );
    }

    // Append memory format instructions when memory is enabled
    final memoryEnabled = prefs.getBool('memory_enabled') ?? false;
    if (memoryEnabled) {
      systemPrompt =
          '$systemPrompt\n\n'
          '【记忆系统指令】请在每次回复末尾，根据对话中新产生的关键信息，'
          '使用以下格式输出记忆条目（不要展示给用户看，每条单独一行）：\n'
          '[MEMORY:类型] 内容 (importance: 重要性0~1, confidence: 置信度0~1, scope: local/shared/global, tags: 标签1,标签2)\n'
          '[STATE:槽位名] 值 (confidence: 置信度0~1)\n'
          'MEMORY类型可选: fact(事实), event(事件), preference(偏好), boundary(边界), relationship(关系), character_state(角色状态)\n'
          '示例: [MEMORY:preference] 用户喜欢喝咖啡 (importance: 0.9, confidence: 0.8, scope: local, tags: 饮食,偏好)';
    }

    systemPrompt = _regexService.applyMacros(systemPrompt, {
      'user': userName_,
      'char': contact.name,
    });

    final postHistoryParts = <String>[];
    final stPostHistoryInstructions =
        stCharacterCard?.data.postHistoryInstructions ?? '';
    if (stPostHistoryInstructions.isNotEmpty) {
      postHistoryParts.add(
        stRegexScripts.isEmpty
            ? stPostHistoryInstructions
            : _regexService.applyScripts(
                stPostHistoryInstructions,
                stRegexScripts,
                RegexPlacement.worldInfo,
              ),
      );
    }
    if (postHistoryInstructions.isNotEmpty) {
      postHistoryParts.add(postHistoryInstructions);
    }

    final customPrompts =
        promptPreset.customPrompts.where((p) => p.enabled).toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    final afterHistory = <PromptEntry>[];

    for (final cp in customPrompts) {
      if (cp.position == PromptInjectionPosition.afterHistory ||
          cp.position == PromptInjectionPosition.absolute) {
        afterHistory.add(cp);
      }
    }

    for (final cp in afterHistory) {
      postHistoryParts.add(cp.content);
    }

    final postHistoryPrompt = postHistoryParts.isNotEmpty
        ? postHistoryParts.join('\n\n')
        : null;

    return AssembledPrompt(
      systemPrompt: systemPrompt.isEmpty ? null : systemPrompt,
      postHistoryPrompt: postHistoryPrompt,
      worldInfoBefore: wiBeforeText,
      worldInfoAfter: wiAfterText,
    );
  }

  String _resolveMainPrompt(SharedPreferences prefs, PromptPreset preset) {
    if (preset.mainPrompt.isNotEmpty) return preset.mainPrompt;

    final globalEnabled = prefs.getBool('global_prompt_enabled') ?? true;
    if (globalEnabled) {
      return prefs.getString('global_prompt_text') ??
          '你现在是在聊天，并非在现实，请让你的回复更符合聊天时的状态';
    }

    return '';
  }

  CharacterCard? _parseCharacterCard(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final json = const JsonDecoder().convert(jsonStr) as Map<String, dynamic>;
      return CharacterCard.fromAutoDetectJson(json);
    } catch (_) {
      return null;
    }
  }

  STCharacterCard? _parseSTCharacterCard(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return _stCharacterParser.parseJsonString(jsonStr);
    } catch (_) {
      return null;
    }
  }

  List<RegexScript> _loadSTRegexScripts(STCharacterCard? card) {
    final rawScripts = card?.data.extensions['regex_scripts'];
    if (rawScripts == null) return const [];
    try {
      if (rawScripts is List) {
        final scripts = rawScripts
            .whereType<Map>()
            .map(
              (item) =>
                  _stRegexParser.parseMap(Map<String, dynamic>.from(item)),
            )
            .toList();
        return _stRegexMapper.toSoulTalkList(scripts);
      }
      if (rawScripts is Map) {
        final scripts = rawScripts.values
            .whereType<Map>()
            .map(
              (item) =>
                  _stRegexParser.parseMap(Map<String, dynamic>.from(item)),
            )
            .toList();
        return _stRegexMapper.toSoulTalkList(scripts);
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  Future<List<WorldInfoEntry>> _loadWorldInfo(
    SharedPreferences prefs,
    String contactId,
  ) async {
    final jsonStr = prefs.getString('world_info_$contactId');
    if (jsonStr != null) {
      try {
        final list = const JsonDecoder().convert(jsonStr) as List;
        return list
            .map((e) => WorldInfoEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final globalJsonStr = prefs.getString('world_info_global');
    if (globalJsonStr != null) {
      try {
        final list = const JsonDecoder().convert(globalJsonStr) as List;
        return list
            .map((e) => WorldInfoEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return [];
  }

  String _buildAllText(
    Contact contact,
    List<Message> history,
    String userName,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(contact.name);
    buffer.writeln(contact.description);
    buffer.writeln(contact.systemPrompt);
    for (final msg in history.take(10)) {
      buffer.writeln(msg.content);
    }
    return buffer.toString();
  }
}

class AssembledPrompt {
  final String? systemPrompt;
  final String? postHistoryPrompt;
  final String worldInfoBefore;
  final String worldInfoAfter;

  const AssembledPrompt({
    this.systemPrompt,
    this.postHistoryPrompt,
    this.worldInfoBefore = '',
    this.worldInfoAfter = '',
  });
}
