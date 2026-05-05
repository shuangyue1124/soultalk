import 'dart:convert';

class RegexPlacement {
  static const int mdDisplay = 0;
  static const int userInput = 1;
  static const int aiOutput = 2;
  static const int slashCommand = 3;
  static const int worldInfo = 5;
  static const int reasoning = 6;

  static String label(int value) {
    switch (value) {
      case userInput:
        return '用户输入';
      case aiOutput:
        return 'AI输出';
      case reasoning:
        return '推理内容';
      default:
        return '其他($value)';
    }
  }
}

class RegexScript {
  final String id;
  final String scriptName;
  final String findRegex;
  final String replaceString;
  final List<String> trimStrings;
  final List<int> placement;
  final bool disabled;
  final bool markdownOnly;
  final bool promptOnly;
  final bool runOnEdit;
  final int substituteRegex;
  final int? minDepth;
  final int? maxDepth;

  const RegexScript({
    required this.id,
    required this.scriptName,
    required this.findRegex,
    required this.replaceString,
    this.trimStrings = const [],
    this.placement = const [],
    this.disabled = false,
    this.markdownOnly = false,
    this.promptOnly = false,
    this.runOnEdit = false,
    this.substituteRegex = 0,
    this.minDepth,
    this.maxDepth,
  });

  RegexScript copyWith({
    String? id,
    String? scriptName,
    String? findRegex,
    String? replaceString,
    List<String>? trimStrings,
    List<int>? placement,
    bool? disabled,
    bool? markdownOnly,
    bool? promptOnly,
    bool? runOnEdit,
    int? substituteRegex,
    int? minDepth,
    int? maxDepth,
  }) {
    return RegexScript(
      id: id ?? this.id,
      scriptName: scriptName ?? this.scriptName,
      findRegex: findRegex ?? this.findRegex,
      replaceString: replaceString ?? this.replaceString,
      trimStrings: trimStrings ?? this.trimStrings,
      placement: placement ?? this.placement,
      disabled: disabled ?? this.disabled,
      markdownOnly: markdownOnly ?? this.markdownOnly,
      promptOnly: promptOnly ?? this.promptOnly,
      runOnEdit: runOnEdit ?? this.runOnEdit,
      substituteRegex: substituteRegex ?? this.substituteRegex,
      minDepth: minDepth ?? this.minDepth,
      maxDepth: maxDepth ?? this.maxDepth,
    );
  }

  factory RegexScript.fromJson(Map<String, dynamic> json) {
    return RegexScript(
      id: json['id'] as String? ?? '',
      scriptName: json['scriptName'] as String? ?? '',
      findRegex: json['findRegex'] as String? ?? '',
      replaceString: json['replaceString'] as String? ?? '',
      trimStrings:
          (json['trimStrings'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      placement:
          (json['placement'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      disabled: json['disabled'] as bool? ?? false,
      markdownOnly: json['markdownOnly'] as bool? ?? false,
      promptOnly: json['promptOnly'] as bool? ?? false,
      runOnEdit: json['runOnEdit'] as bool? ?? false,
      substituteRegex: (json['substituteRegex'] as num?)?.toInt() ?? 0,
      minDepth: (json['minDepth'] as num?)?.toInt(),
      maxDepth: (json['maxDepth'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scriptName': scriptName,
      'findRegex': findRegex,
      'replaceString': replaceString,
      'trimStrings': trimStrings,
      'placement': placement,
      'disabled': disabled,
      'markdownOnly': markdownOnly,
      'promptOnly': promptOnly,
      'runOnEdit': runOnEdit,
      'substituteRegex': substituteRegex,
      'minDepth': minDepth,
      'maxDepth': maxDepth,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'script_name': scriptName,
      'find_regex': findRegex,
      'replace_string': replaceString,
      'trim_strings': jsonEncode(trimStrings),
      'placement': jsonEncode(placement),
      'disabled': disabled ? 1 : 0,
      'markdown_only': markdownOnly ? 1 : 0,
      'prompt_only': promptOnly ? 1 : 0,
      'run_on_edit': runOnEdit ? 1 : 0,
      'substitute_regex': substituteRegex,
      'min_depth': minDepth,
      'max_depth': maxDepth,
    };
  }

  factory RegexScript.fromDbMap(Map<String, dynamic> map) {
    return RegexScript(
      id: map['id'] as String? ?? '',
      scriptName: map['script_name'] as String? ?? '',
      findRegex: map['find_regex'] as String? ?? '',
      replaceString: map['replace_string'] as String? ?? '',
      trimStrings: (jsonDecode(map['trim_strings'] as String? ?? '[]') as List)
          .map((e) => e.toString())
          .toList(),
      placement: (jsonDecode(map['placement'] as String? ?? '[]') as List)
          .map((e) => (e as num).toInt())
          .toList(),
      disabled: (map['disabled'] as int?) == 1,
      markdownOnly: (map['markdown_only'] as int?) == 1,
      promptOnly: (map['prompt_only'] as int?) == 1,
      runOnEdit: (map['run_on_edit'] as int?) == 1,
      substituteRegex: map['substitute_regex'] as int? ?? 0,
      minDepth: map['min_depth'] as int?,
      maxDepth: map['max_depth'] as int?,
    );
  }

  /// Parse SillyTavern export format: supports both numbered-key objects and arrays
  static List<RegexScript> fromSillyTavernJson(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is List) {
      return decoded
          .map((e) => RegexScript.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('scriptName')) {
        return [RegexScript.fromJson(decoded)];
      }
      final scripts = <RegexScript>[];
      final sortedKeys = decoded.keys.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a);
          final bi = int.tryParse(b);
          if (ai != null && bi != null) return ai.compareTo(bi);
          return a.compareTo(b);
        });
      for (final key in sortedKeys) {
        final value = decoded[key];
        if (value is Map<String, dynamic>) {
          scripts.add(RegexScript.fromJson(value));
        }
      }
      return scripts;
    }

    return [];
  }
}
