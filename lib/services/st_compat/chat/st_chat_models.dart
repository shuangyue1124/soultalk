class STChatFile {
  final STChatMetadata? metadata;
  final List<STChatMessage> messages;

  const STChatFile({required this.metadata, required this.messages});
}

class STChatMetadata {
  final String userName;
  final String characterName;
  final String createDate;
  final Map<String, dynamic> chatMetadata;
  final Map<String, dynamic> raw;

  const STChatMetadata({
    required this.userName,
    required this.characterName,
    required this.createDate,
    required this.chatMetadata,
    required this.raw,
  });
}

class STChatMessage {
  final String name;
  final bool isUser;
  final bool isSystem;
  final String sendDate;
  final String mes;
  final Map<String, dynamic> extra;
  final Map<String, dynamic> raw;

  const STChatMessage({
    required this.name,
    required this.isUser,
    required this.isSystem,
    required this.sendDate,
    required this.mes,
    required this.extra,
    required this.raw,
  });
}
