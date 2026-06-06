import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/character/st_character_card_parser.dart';

void main() {
  test('parses v2 character json and keeps extensions', () {
    final parser = STCharacterCardParser();
    final card = parser.parseJsonString(
      jsonEncode({
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {
          'name': 'Alice',
          'description': 'A character',
          'personality': 'Warm',
          'scenario': 'Cafe',
          'first_mes': 'Hello',
          'mes_example': '<START>',
          'system_prompt': 'Stay in character',
          'post_history_instructions': 'Continue naturally',
          'tags': ['friend'],
          'alternate_greetings': ['Hi'],
          'group_only_greetings': ['Hi all'],
          'extensions': {
            'soultalk': {'enabled': true},
          },
          'character_book': {'entries': {}},
        },
      }),
    );

    expect(card.spec, 'chara_card_v2');
    expect(card.name, 'Alice');
    expect(card.data.extensions['soultalk'], {'enabled': true});
    expect(card.data.characterBook, {'entries': {}});
  });

  test('parses png chara text chunk with base64 json payload', () {
    final payload = base64.encode(
      utf8.encode(
        jsonEncode({
          'spec': 'chara_card_v2',
          'data': {'name': 'PngAlice'},
        }),
      ),
    );

    final png = _minimalPngWithTextChunk('chara', payload);
    final card = STCharacterCardParser().parsePngBytes(png);

    expect(card.name, 'PngAlice');
  });
}

Uint8List _minimalPngWithTextChunk(String key, String value) {
  final bytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  bytes.addAll(
    _chunk('tEXt', [...latin1.encode(key), 0, ...latin1.encode(value)]),
  );
  bytes.addAll(_chunk('IEND', const []));
  return Uint8List.fromList(bytes);
}

List<int> _chunk(String type, List<int> data) {
  final result = <int>[];
  result.addAll(_uint32(data.length));
  result.addAll(ascii.encode(type));
  result.addAll(data);
  result.addAll(_uint32(0));
  return result;
}

List<int> _uint32(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];
