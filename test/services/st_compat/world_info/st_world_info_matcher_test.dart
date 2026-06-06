import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/world_info/st_world_info_matcher.dart';
import 'package:soultalk/services/st_compat/world_info/st_world_info_parser.dart';

void main() {
  test('matches constant entries and sorts by order', () {
    final lorebook = STWorldInfoParser().parseJsonString(
      jsonEncode({
        'entries': {
          '2': {
            'uid': 2,
            'key': ['missing'],
            'content': 'Second',
            'constant': true,
            'order': 20,
          },
          '1': {
            'uid': 1,
            'key': ['missing'],
            'content': 'First',
            'constant': true,
            'order': 10,
          },
        },
      }),
    );

    final matched = STWorldInfoMatcher().match(
      lorebook: lorebook,
      recentMessages: ['hello'],
    );

    expect(matched.map((entry) => entry.uid), [1, 2]);
  });

  test(
    'matches selective entries only when primary and secondary keys match',
    () {
      final lorebook = STWorldInfoParser().parseJsonString(
        jsonEncode({
          'entries': {
            '1': {
              'uid': 1,
              'key': ['city'],
              'keysecondary': ['rain'],
              'content': 'Rain city',
              'selective': true,
            },
          },
        }),
      );

      final matcher = STWorldInfoMatcher();

      expect(
        matcher.match(lorebook: lorebook, recentMessages: ['city only']),
        isEmpty,
      );
      expect(
        matcher.match(lorebook: lorebook, recentMessages: ['city rain']),
        hasLength(1),
      );
    },
  );

  test('supports regex keywords and disabled entries', () {
    final lorebook = STWorldInfoParser().parseJsonString(
      jsonEncode({
        'entries': {
          '1': {
            'uid': 1,
            'key': ['/cat\\s+girl/i'],
            'content': 'Regex match',
          },
          '2': {
            'uid': 2,
            'key': ['cat'],
            'content': 'Disabled',
            'disable': true,
          },
        },
      }),
    );

    final matched = STWorldInfoMatcher().match(
      lorebook: lorebook,
      recentMessages: ['A CAT girl appears.'],
    );

    expect(matched.map((entry) => entry.uid), [1]);
  });

  test('honors probability when enabled', () {
    final lorebook = STWorldInfoParser().parseJsonString(
      jsonEncode({
        'entries': {
          '1': {
            'uid': 1,
            'key': ['cat'],
            'content': 'Never',
            'useProbability': true,
            'probability': 0,
          },
        },
      }),
    );

    final matched = STWorldInfoMatcher(
      random: Random(1),
    ).match(lorebook: lorebook, recentMessages: ['cat']);

    expect(matched, isEmpty);
  });
}
