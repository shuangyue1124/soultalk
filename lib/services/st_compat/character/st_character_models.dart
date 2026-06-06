class STCharacterCard {
  final String? spec;
  final String? specVersion;
  final String name;
  final STCharacterData data;
  final Map<String, dynamic> raw;

  const STCharacterCard({
    required this.spec,
    required this.specVersion,
    required this.name,
    required this.data,
    required this.raw,
  });
}

class STCharacterData {
  final String name;
  final String description;
  final String personality;
  final String scenario;
  final String firstMes;
  final String mesExample;
  final String systemPrompt;
  final String postHistoryInstructions;
  final List<String> tags;
  final List<String> alternateGreetings;
  final List<String> groupOnlyGreetings;
  final Map<String, dynamic> extensions;
  final Map<String, dynamic>? characterBook;

  const STCharacterData({
    required this.name,
    required this.description,
    required this.personality,
    required this.scenario,
    required this.firstMes,
    required this.mesExample,
    required this.systemPrompt,
    required this.postHistoryInstructions,
    required this.tags,
    required this.alternateGreetings,
    required this.groupOnlyGreetings,
    required this.extensions,
    required this.characterBook,
  });
}
