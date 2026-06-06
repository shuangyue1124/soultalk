class STWorldInfoLorebook {
  final Map<String, STWorldInfoEntry> entries;
  final Map<String, dynamic> raw;

  const STWorldInfoLorebook({required this.entries, required this.raw});
}

class STWorldInfoEntry {
  final int uid;
  final List<String> key;
  final List<String> keySecondary;
  final String comment;
  final String content;
  final bool constant;
  final bool selective;
  final int order;
  final int position;
  final bool disable;
  final int displayIndex;
  final bool addMemo;
  final String group;
  final bool groupOverride;
  final int groupWeight;
  final int sticky;
  final int cooldown;
  final int delay;
  final int probability;
  final int depth;
  final bool useProbability;
  final int? role;
  final bool vectorized;
  final bool excludeRecursion;
  final bool preventRecursion;
  final bool delayUntilRecursion;
  final int? scanDepth;
  final bool? caseSensitive;
  final bool? matchWholeWords;
  final bool? useGroupScoring;
  final String automationId;
  final Map<String, dynamic> raw;

  const STWorldInfoEntry({
    required this.uid,
    required this.key,
    required this.keySecondary,
    required this.comment,
    required this.content,
    required this.constant,
    required this.selective,
    required this.order,
    required this.position,
    required this.disable,
    required this.displayIndex,
    required this.addMemo,
    required this.group,
    required this.groupOverride,
    required this.groupWeight,
    required this.sticky,
    required this.cooldown,
    required this.delay,
    required this.probability,
    required this.depth,
    required this.useProbability,
    required this.role,
    required this.vectorized,
    required this.excludeRecursion,
    required this.preventRecursion,
    required this.delayUntilRecursion,
    required this.scanDepth,
    required this.caseSensitive,
    required this.matchWholeWords,
    required this.useGroupScoring,
    required this.automationId,
    required this.raw,
  });
}
