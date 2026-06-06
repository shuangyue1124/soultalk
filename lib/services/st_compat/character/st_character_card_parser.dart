import 'dart:convert';
import 'dart:typed_data';

import 'st_character_models.dart';
import 'st_character_png_codec.dart';

class STCharacterCardParser {
  final STCharacterPngCodec pngCodec;

  const STCharacterCardParser({STCharacterPngCodec? pngCodec})
    : pngCodec = pngCodec ?? const STCharacterPngCodec();

  STCharacterCard parseJsonString(String contents) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Character card JSON must be an object.');
    }
    return parseMap(decoded);
  }

  STCharacterCard parsePngBytes(Uint8List bytes) {
    final charaText = pngCodec.readCharaText(bytes);
    if (charaText == null) {
      throw const FormatException('PNG does not contain a chara text chunk.');
    }

    final jsonText = _decodeCharaPayload(charaText);
    return parseJsonString(jsonText);
  }

  STCharacterCard parseMap(Map<String, dynamic> raw) {
    final dataMap = raw['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw;

    final data = STCharacterData(
      name: _string(dataMap['name'], fallback: _string(raw['name'])),
      description: _string(
        dataMap['description'],
        fallback: _string(raw['description']),
      ),
      personality: _string(
        dataMap['personality'],
        fallback: _string(raw['personality']),
      ),
      scenario: _string(
        dataMap['scenario'],
        fallback: _string(raw['scenario']),
      ),
      firstMes: _string(
        dataMap['first_mes'],
        fallback: _string(raw['first_mes']),
      ),
      mesExample: _string(
        dataMap['mes_example'],
        fallback: _string(raw['mes_example']),
      ),
      systemPrompt: _string(dataMap['system_prompt']),
      postHistoryInstructions: _string(dataMap['post_history_instructions']),
      tags: _stringList(dataMap['tags'] ?? raw['tags']),
      alternateGreetings: _stringList(dataMap['alternate_greetings']),
      groupOnlyGreetings: _stringList(dataMap['group_only_greetings']),
      extensions: _map(dataMap['extensions']),
      characterBook: dataMap['character_book'] is Map
          ? Map<String, dynamic>.from(dataMap['character_book'] as Map)
          : null,
    );

    return STCharacterCard(
      spec: _nullableString(raw['spec']),
      specVersion: _nullableString(raw['spec_version']),
      name: data.name.isNotEmpty ? data.name : _string(raw['name']),
      data: data,
      raw: Map<String, dynamic>.from(raw),
    );
  }

  String _decodeCharaPayload(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{')) return trimmed;

    try {
      return utf8.decode(base64.decode(trimmed));
    } on FormatException {
      return trimmed;
    }
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

  List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
