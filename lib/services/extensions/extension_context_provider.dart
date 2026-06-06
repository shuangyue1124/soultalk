import '../../models/contact.dart';
import '../../models/extension_context.dart';
import '../../models/message.dart';

class ExtensionContextProvider {
  ExtensionContext build({
    Contact? contact,
    List<Message> messages = const [],
    String userName = 'User',
    bool isStreaming = false,
    String? lastMessageId,
  }) {
    return ExtensionContext({
      'app': 'SoulTalk',
      'compatibility': {'sillyTavern': true, 'level': 'L2/L3', 'apiVersion': 1},
      'characterId': contact?.id,
      'characterName': contact?.name,
      'chatId': contact?.id,
      'messages': messages
          .map(
            (message) => {
              'id': message.id,
              'role': message.role.name,
              'content': message.content,
              'type': message.type.name,
              'createdAt': message.createdAt?.toIso8601String(),
              'metadata': message.metadata,
            },
          )
          .toList(),
      'user': {'name': userName},
      'generation': {
        'isStreaming': isStreaming,
        'lastMessageId': lastMessageId,
      },
      'extensionSettings': <String, dynamic>{},
    });
  }
}
