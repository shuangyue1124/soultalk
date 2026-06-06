import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/st_compat/chat/st_chat_jsonl_codec.dart';

void main() {
  test('parses metadata first line and message extra fields', () {
    final jsonl = [
      jsonEncode({
        'user_name': 'User',
        'character_name': 'Alice',
        'create_date': '2026-05-23T00:00:00Z',
        'chat_metadata': {
          'chat_id_hash': 123,
          'extensions': {
            'my_ext': {'enabled': true},
          },
        },
      }),
      jsonEncode({
        'name': 'User',
        'is_user': true,
        'is_system': false,
        'send_date': '2026-05-23T00:01:00Z',
        'mes': 'Hello',
        'extra': {
          'api': 'claude',
          'swipes': ['Hello'],
        },
        'unknown': 'kept',
      }),
    ].join('\n');

    final chat = STChatJsonlCodec().parseString(jsonl);

    expect(chat.metadata!.userName, 'User');
    expect(chat.metadata!.chatMetadata['extensions'], {
      'my_ext': {'enabled': true},
    });
    expect(chat.messages.single.isUser, isTrue);
    expect(chat.messages.single.extra['api'], 'claude');
    expect(chat.messages.single.raw['unknown'], 'kept');
  });

  test('parses jsonl without metadata as messages only', () {
    final jsonl = jsonEncode({
      'name': 'Alice',
      'is_user': false,
      'is_system': false,
      'send_date': '2026-05-23T00:02:00Z',
      'mes': 'Hi',
    });

    final chat = STChatJsonlCodec().parseString(jsonl);

    expect(chat.metadata, isNull);
    expect(chat.messages.single.name, 'Alice');
  });

  test('encodes parsed raw objects back to jsonl lines', () {
    final codec = STChatJsonlCodec();
    final chat = codec.parseString(
      [
        jsonEncode({'user_name': 'User', 'character_name': 'Alice'}),
        jsonEncode({'name': 'Alice', 'mes': 'Hi'}),
      ].join('\n'),
    );

    final lines = codec.encode(chat);

    expect(lines, hasLength(2));
    expect(jsonDecode(lines.first)['character_name'], 'Alice');
    expect(jsonDecode(lines.last)['mes'], 'Hi');
  });
}
