import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/regex_script.dart';
import 'package:soultalk/services/st_compat/regex/st_regex_mapper.dart';
import 'package:soultalk/services/st_compat/regex/st_regex_parser.dart';

void main() {
  test('maps SillyTavern regex script to SoulTalk regex script', () {
    final stScript = STRegexParser().parseMap({
      'id': 'r1',
      'scriptName': 'World replace',
      'trigger': 'foo',
      'replace': 'bar',
      'trim': 'trim-me',
      'opts': {
        'disabled': false,
        'runOnEdit': true,
        'substituteRegex': 1,
        'minDepth': -1,
        'maxDepth': 4,
        'ephemeralDisplay': true,
        'ephemeralPrompt': true,
        'source': ['worldInfo', 'aiOutput'],
        'flags': 'g',
      },
    });

    final script = STRegexMapper().toSoulTalk(stScript);

    expect(script.id, 'r1');
    expect(script.findRegex, 'foo');
    expect(script.replaceString, 'bar');
    expect(script.trimStrings, ['trim-me']);
    expect(script.placement, [
      RegexPlacement.worldInfo,
      RegexPlacement.aiOutput,
    ]);
    expect(script.minDepth, isNull);
    expect(script.maxDepth, 4);
    expect(script.markdownOnly, isTrue);
    expect(script.promptOnly, isTrue);
  });

  test(
    'character card regex scripts are available as list or map payloads',
    () {
      final listPayload = STRegexParser().parseListJsonString(
        jsonEncode([
          {
            'scriptName': 'A',
            'trigger': 'a',
            'replace': 'b',
            'opts': {
              'source': ['worldInfo'],
            },
          },
        ]),
      );

      final mapped = STRegexMapper().toSoulTalkList(listPayload);

      expect(mapped.single.placement, [RegexPlacement.worldInfo]);
    },
  );
}
