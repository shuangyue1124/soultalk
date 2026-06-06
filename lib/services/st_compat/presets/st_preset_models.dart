class STPreset {
  final String apiId;
  final String name;
  final Map<String, dynamic> raw;

  const STPreset({required this.apiId, required this.name, required this.raw});
}

class STPromptTemplate {
  final String identifier;
  final String name;
  final bool systemPrompt;
  final String role;
  final String content;
  final bool marker;
  final Map<String, dynamic> raw;

  const STPromptTemplate({
    required this.identifier,
    required this.name,
    required this.systemPrompt,
    required this.role,
    required this.content,
    required this.marker,
    required this.raw,
  });
}

class STOpenAIPreset extends STPreset {
  final String chatCompletionSource;
  final String openaiModel;
  final String claudeModel;
  final double temperature;
  final int maxContext;
  final int maxTokens;
  final bool stream;
  final List<STPromptTemplate> prompts;

  const STOpenAIPreset({
    required super.apiId,
    required super.name,
    required super.raw,
    required this.chatCompletionSource,
    required this.openaiModel,
    required this.claudeModel,
    required this.temperature,
    required this.maxContext,
    required this.maxTokens,
    required this.stream,
    required this.prompts,
  });
}

class STContextPreset extends STPreset {
  final String storyString;
  final String exampleSeparator;
  final String chatStart;

  const STContextPreset({
    required super.apiId,
    required super.name,
    required super.raw,
    required this.storyString,
    required this.exampleSeparator,
    required this.chatStart,
  });
}

class STInstructPreset extends STPreset {
  final String inputSequence;
  final String outputSequence;
  final String systemSequence;
  final String stopSequence;

  const STInstructPreset({
    required super.apiId,
    required super.name,
    required super.raw,
    required this.inputSequence,
    required this.outputSequence,
    required this.systemSequence,
    required this.stopSequence,
  });
}
