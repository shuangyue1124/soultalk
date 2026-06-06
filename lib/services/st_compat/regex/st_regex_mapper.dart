import '../../../models/regex_script.dart';
import 'st_regex_models.dart';

class STRegexMapper {
  RegexScript toSoulTalk(STRegexScript script) {
    return RegexScript(
      id: script.id ?? script.scriptName,
      scriptName: script.scriptName,
      findRegex: script.trigger,
      replaceString: script.replace,
      trimStrings: _trimStrings(script.trim),
      placement: script.opts.source
          .map(_placementFor)
          .whereType<int>()
          .toList(),
      disabled: script.opts.disabled,
      markdownOnly: script.opts.ephemeralDisplay,
      promptOnly: script.opts.ephemeralPrompt,
      runOnEdit: script.opts.runOnEdit,
      substituteRegex: script.opts.substituteRegex,
      minDepth: script.opts.minDepth == -1 ? null : script.opts.minDepth,
      maxDepth: script.opts.maxDepth == -1 ? null : script.opts.maxDepth,
    );
  }

  List<RegexScript> toSoulTalkList(List<STRegexScript> scripts) {
    return scripts.map(toSoulTalk).toList();
  }

  List<String> _trimStrings(String trim) {
    if (trim.trim().isEmpty) return const [];
    return trim.split('\n').where((item) => item.isNotEmpty).toList();
  }

  int? _placementFor(STRegexSource source) {
    return switch (source) {
      STRegexSource.userInput => RegexPlacement.userInput,
      STRegexSource.aiOutput => RegexPlacement.aiOutput,
      STRegexSource.slashCommand => RegexPlacement.slashCommand,
      STRegexSource.worldInfo => RegexPlacement.worldInfo,
      STRegexSource.reasoning => RegexPlacement.reasoning,
    };
  }
}
