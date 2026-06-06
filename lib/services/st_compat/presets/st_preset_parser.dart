import 'dart:convert';

import 'st_preset_models.dart';

class STPresetParser {
  STPreset parseJsonString({
    required String apiId,
    required String name,
    required String contents,
  }) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Preset JSON must be an object.');
    }
    return parseMap(apiId: apiId, name: name, raw: decoded);
  }

  STPreset parseMap({
    required String apiId,
    required String name,
    required Map<String, dynamic> raw,
  }) {
    return switch (apiId) {
      'openai' => _parseOpenAI(apiId, name, raw),
      'context' => STContextPreset(
        apiId: apiId,
        name: _string(raw['name'], fallback: name),
        raw: Map<String, dynamic>.from(raw),
        storyString: _string(raw['story_string']),
        exampleSeparator: _string(raw['example_separator']),
        chatStart: _string(raw['chat_start']),
      ),
      'instruct' => STInstructPreset(
        apiId: apiId,
        name: _string(raw['name'], fallback: name),
        raw: Map<String, dynamic>.from(raw),
        inputSequence: _string(raw['input_sequence']),
        outputSequence: _string(raw['output_sequence']),
        systemSequence: _string(raw['system_sequence']),
        stopSequence: _string(raw['stop_sequence']),
      ),
      _ => STPreset(
        apiId: apiId,
        name: _string(raw['name'], fallback: name),
        raw: Map<String, dynamic>.from(raw),
      ),
    };
  }

  STOpenAIPreset _parseOpenAI(
    String apiId,
    String name,
    Map<String, dynamic> raw,
  ) {
    return STOpenAIPreset(
      apiId: apiId,
      name: _string(raw['name'], fallback: name),
      raw: Map<String, dynamic>.from(raw),
      chatCompletionSource: _string(raw['chat_completion_source']),
      openaiModel: _string(raw['openai_model']),
      claudeModel: _string(raw['claude_model']),
      temperature: _double(raw['temperature'], fallback: 1),
      maxContext: _int(raw['openai_max_context']),
      maxTokens: _int(raw['openai_max_tokens']),
      stream: _bool(raw['stream_openai']),
      prompts: _promptTemplates(raw['prompts']),
    );
  }

  List<STPromptTemplate> _promptTemplates(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      final raw = Map<String, dynamic>.from(item);
      return STPromptTemplate(
        identifier: _string(raw['identifier']),
        name: _string(raw['name']),
        systemPrompt: _bool(raw['system_prompt']),
        role: _string(raw['role']),
        content: _string(raw['content']),
        marker: _bool(raw['marker']),
        raw: raw,
      );
    }).toList();
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _double(Object? value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return fallback;
  }
}
