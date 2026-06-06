import 'dart:math';

import 'st_world_info_models.dart';

class STWorldInfoMatcher {
  final Random random;

  STWorldInfoMatcher({Random? random}) : random = random ?? Random();

  List<STWorldInfoEntry> match({
    required STWorldInfoLorebook lorebook,
    required List<String> recentMessages,
  }) {
    final text = recentMessages.join('\n');
    final matched = <STWorldInfoEntry>[];

    for (final entry in lorebook.entries.values) {
      if (entry.disable) continue;
      if (!_passesProbability(entry)) continue;
      if (entry.constant || _matchesEntry(entry, text)) {
        matched.add(entry);
      }
    }

    matched.sort((a, b) {
      final order = a.order.compareTo(b.order);
      if (order != 0) return order;
      return a.uid.compareTo(b.uid);
    });
    return matched;
  }

  bool _matchesEntry(STWorldInfoEntry entry, String text) {
    final primary = _matchesAny(entry.key, text, entry);
    if (!primary) return false;
    if (!entry.selective) return true;
    return _matchesAny(entry.keySecondary, text, entry);
  }

  bool _matchesAny(List<String> keys, String text, STWorldInfoEntry entry) {
    for (final key in keys) {
      if (_matchesKey(key, text, entry)) return true;
    }
    return false;
  }

  bool _matchesKey(String key, String text, STWorldInfoEntry entry) {
    if (key.length >= 2 && key.startsWith('/')) {
      final lastSlash = key.lastIndexOf('/');
      if (lastSlash > 0) {
        final pattern = key.substring(1, lastSlash);
        final flags = key.substring(lastSlash + 1);
        return RegExp(
          pattern,
          caseSensitive: flags.contains('i') ? false : _caseSensitive(entry),
          multiLine: flags.contains('m'),
          dotAll: flags.contains('s'),
          unicode: flags.contains('u'),
        ).hasMatch(text);
      }
    }

    final caseSensitive = _caseSensitive(entry);
    final haystack = caseSensitive ? text : text.toLowerCase();
    final needle = caseSensitive ? key : key.toLowerCase();
    if (_matchWholeWords(entry)) {
      return RegExp(
        r'(?<![\p{L}\p{N}_])' + RegExp.escape(needle) + r'(?![\p{L}\p{N}_])',
        unicode: true,
      ).hasMatch(haystack);
    }
    return haystack.contains(needle);
  }

  bool _passesProbability(STWorldInfoEntry entry) {
    if (!entry.useProbability) return true;
    final probability = entry.probability.clamp(0, 100);
    return random.nextInt(100) < probability;
  }

  bool _caseSensitive(STWorldInfoEntry entry) => entry.caseSensitive ?? false;
  bool _matchWholeWords(STWorldInfoEntry entry) =>
      entry.matchWholeWords ?? false;
}
