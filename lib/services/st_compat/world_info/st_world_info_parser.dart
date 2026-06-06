import 'dart:convert';

import 'st_world_info_models.dart';

class STWorldInfoParser {
  STWorldInfoLorebook parseJsonString(String contents) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('World info JSON must be an object.');
    }
    return parseMap(decoded);
  }

  STWorldInfoLorebook parseMap(Map<String, dynamic> raw) {
    final entriesRaw = raw['entries'];
    if (entriesRaw is! Map) {
      throw const FormatException('World info must contain an entries object.');
    }

    final entries = <String, STWorldInfoEntry>{};
    for (final entry in entriesRaw.entries) {
      if (entry.value is! Map) continue;
      entries[entry.key.toString()] = _parseEntry(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    return STWorldInfoLorebook(
      entries: entries,
      raw: Map<String, dynamic>.from(raw),
    );
  }

  STWorldInfoEntry _parseEntry(Map<String, dynamic> raw) {
    return STWorldInfoEntry(
      uid: _int(raw['uid']),
      key: _stringList(raw['key']),
      keySecondary: _stringList(raw['keysecondary']),
      comment: _string(raw['comment']),
      content: _string(raw['content']),
      constant: _bool(raw['constant']),
      selective: _bool(raw['selective']),
      order: _int(raw['order']),
      position: _int(raw['position']),
      disable: _bool(raw['disable']),
      displayIndex: _int(raw['displayIndex']),
      addMemo: _bool(raw['addMemo']),
      group: _string(raw['group']),
      groupOverride: _bool(raw['groupOverride']),
      groupWeight: _int(raw['groupWeight']),
      sticky: _int(raw['sticky']),
      cooldown: _int(raw['cooldown']),
      delay: _int(raw['delay']),
      probability: _int(raw['probability'], fallback: 100),
      depth: _int(raw['depth'], fallback: 4),
      useProbability: _bool(raw['useProbability']),
      role: _nullableInt(raw['role']),
      vectorized: _bool(raw['vectorized']),
      excludeRecursion: _bool(raw['excludeRecursion']),
      preventRecursion: _bool(raw['preventRecursion']),
      delayUntilRecursion: _bool(raw['delayUntilRecursion']),
      scanDepth: _nullableInt(raw['scanDepth']),
      caseSensitive: _nullableBool(raw['caseSensitive']),
      matchWholeWords: _nullableBool(raw['matchWholeWords']),
      useGroupScoring: _nullableBool(raw['useGroupScoring']),
      automationId: _string(raw['automationId']),
      raw: raw,
    );
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

  int? _nullableInt(Object? value) {
    if (value == null) return null;
    return _int(value);
  }

  bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return fallback;
  }

  bool? _nullableBool(Object? value) {
    if (value == null) return null;
    return _bool(value);
  }

  List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
