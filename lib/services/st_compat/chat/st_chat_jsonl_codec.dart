import 'dart:convert';

import 'st_chat_models.dart';

class STChatJsonlCodec {
  STChatFile parseString(String contents) {
    final lines = const LineSplitter()
        .convert(contents)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const STChatFile(metadata: null, messages: []);
    }

    var startIndex = 0;
    STChatMetadata? metadata;
    final first = _decodeLine(lines.first);
    if (_looksLikeMetadata(first)) {
      metadata = _parseMetadata(first);
      startIndex = 1;
    }

    final messages = <STChatMessage>[];
    for (var i = startIndex; i < lines.length; i++) {
      messages.add(_parseMessage(_decodeLine(lines[i])));
    }

    return STChatFile(metadata: metadata, messages: messages);
  }

  List<String> encode(STChatFile chat) {
    final lines = <String>[];
    if (chat.metadata != null) {
      lines.add(jsonEncode(chat.metadata!.raw));
    }
    lines.addAll(chat.messages.map((message) => jsonEncode(message.raw)));
    return lines;
  }

  Map<String, dynamic> _decodeLine(String line) {
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Each JSONL line must be an object.');
    }
    return decoded;
  }

  bool _looksLikeMetadata(Map<String, dynamic> raw) {
    return raw.containsKey('chat_metadata') ||
        raw.containsKey('user_name') && raw.containsKey('character_name');
  }

  STChatMetadata _parseMetadata(Map<String, dynamic> raw) {
    return STChatMetadata(
      userName: _string(raw['user_name']),
      characterName: _string(raw['character_name']),
      createDate: _string(raw['create_date']),
      chatMetadata: raw['chat_metadata'] is Map
          ? Map<String, dynamic>.from(raw['chat_metadata'] as Map)
          : <String, dynamic>{},
      raw: Map<String, dynamic>.from(raw),
    );
  }

  STChatMessage _parseMessage(Map<String, dynamic> raw) {
    return STChatMessage(
      name: _string(raw['name']),
      isUser: _bool(raw['is_user']),
      isSystem: _bool(raw['is_system']),
      sendDate: _string(raw['send_date']),
      mes: _string(raw['mes']),
      extra: raw['extra'] is Map
          ? Map<String, dynamic>.from(raw['extra'] as Map)
          : <String, dynamic>{},
      raw: Map<String, dynamic>.from(raw),
    );
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return fallback;
  }
}
