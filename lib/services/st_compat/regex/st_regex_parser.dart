import 'dart:convert';

import 'st_regex_models.dart';

class STRegexParser {
  List<STRegexScript> parseListJsonString(String contents) {
    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('Regex JSON must be a list.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => parseMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  STRegexScript parseMap(Map<String, dynamic> raw) {
    final opts = raw['opts'] is Map
        ? Map<String, dynamic>.from(raw['opts'] as Map)
        : <String, dynamic>{};

    return STRegexScript(
      id: _nullableString(raw['id']),
      scriptName: _string(raw['scriptName']),
      trigger: _string(raw['trigger']),
      replace: _string(raw['replace']),
      trim: _string(raw['trim']),
      opts: STRegexOptions(
        disabled: _bool(opts['disabled']),
        runOnEdit: _bool(opts['runOnEdit']),
        substituteRegex: _int(opts['substituteRegex']),
        minDepth: _int(opts['minDepth'], fallback: -1),
        maxDepth: _int(opts['maxDepth'], fallback: -1),
        ephemeral: _bool(opts['ephemeral']),
        ephemeralDisplay: _bool(opts['ephemeralDisplay']),
        ephemeralPrompt: _bool(opts['ephemeralPrompt']),
        source: _sources(opts['source']),
        flags: _string(opts['flags']),
      ),
      isDefault: _bool(raw['isDefault']),
      raw: Map<String, dynamic>.from(raw),
    );
  }

  List<STRegexSource> _sources(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString())
        .map((item) {
          return switch (item) {
            'userInput' => STRegexSource.userInput,
            'aiOutput' => STRegexSource.aiOutput,
            'slashCommand' => STRegexSource.slashCommand,
            'worldInfo' => STRegexSource.worldInfo,
            'reasoning' => STRegexSource.reasoning,
            _ => null,
          };
        })
        .whereType<STRegexSource>()
        .toList();
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  String? _nullableString(Object? value) {
    if (value == null) return null;
    return _string(value);
  }

  int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return fallback;
  }
}
