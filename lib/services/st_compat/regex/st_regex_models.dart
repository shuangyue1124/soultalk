enum STRegexSource { userInput, aiOutput, slashCommand, worldInfo, reasoning }

class STRegexScript {
  final String? id;
  final String scriptName;
  final String trigger;
  final String replace;
  final String trim;
  final STRegexOptions opts;
  final bool isDefault;
  final Map<String, dynamic> raw;

  const STRegexScript({
    required this.id,
    required this.scriptName,
    required this.trigger,
    required this.replace,
    required this.trim,
    required this.opts,
    required this.isDefault,
    required this.raw,
  });
}

class STRegexOptions {
  final bool disabled;
  final bool runOnEdit;
  final int substituteRegex;
  final int minDepth;
  final int maxDepth;
  final bool ephemeral;
  final bool ephemeralDisplay;
  final bool ephemeralPrompt;
  final List<STRegexSource> source;
  final String flags;

  const STRegexOptions({
    required this.disabled,
    required this.runOnEdit,
    required this.substituteRegex,
    required this.minDepth,
    required this.maxDepth,
    required this.ephemeral,
    required this.ephemeralDisplay,
    required this.ephemeralPrompt,
    required this.source,
    required this.flags,
  });
}
