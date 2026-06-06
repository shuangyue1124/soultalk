import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/regex/st_regex_models.dart';
import 'package:soultalk/services/st_compat/regex/st_regex_parser.dart';

void main() {
  test('parses regex script options and sources', () {
    final scripts = STRegexParser().parseListJsonString(
      jsonEncode([
        {
          'id': 'r1',
          'scriptName': 'Clean output',
          'trigger': 'foo',
          'replace': 'bar',
          'trim': '',
          'opts': {
            'disabled': false,
            'runOnEdit': true,
            'substituteRegex': 1,
            'minDepth': 0,
            'maxDepth': 4,
            'ephemeral': true,
            'ephemeralDisplay': false,
            'ephemeralPrompt': true,
            'source': ['aiOutput', 'worldInfo'],
            'flags': 'gi',
          },
        },
      ]),
    );

    final script = scripts.single;
    expect(script.scriptName, 'Clean output');
    expect(script.opts.runOnEdit, isTrue);
    expect(script.opts.source, [
      STRegexSource.aiOutput,
      STRegexSource.worldInfo,
    ]);
    expect(script.opts.flags, 'gi');
  });
}
