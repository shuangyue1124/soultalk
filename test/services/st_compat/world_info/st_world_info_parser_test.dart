import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/world_info/st_world_info_parser.dart';

void main() {
  test('parses world info entries and keeps raw fields', () {
    final lorebook = STWorldInfoParser().parseJsonString(
      jsonEncode({
        'entries': {
          '1': {
            'uid': 1,
            'key': ['city'],
            'keysecondary': ['rain'],
            'comment': 'City lore',
            'content': 'It always rains here.',
            'constant': false,
            'selective': true,
            'order': 10,
            'position': 1,
            'disable': false,
            'probability': 80,
            'depth': 4,
            'custom_field': 'kept',
          },
        },
      }),
    );

    final entry = lorebook.entries['1']!;
    expect(entry.uid, 1);
    expect(entry.key, ['city']);
    expect(entry.keySecondary, ['rain']);
    expect(entry.selective, isTrue);
    expect(entry.raw['custom_field'], 'kept');
  });
}
