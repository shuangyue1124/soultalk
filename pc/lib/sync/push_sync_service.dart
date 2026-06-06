import '../websocket_client.dart';

class PushSyncService {
  final WebSocketClient client;

  const PushSyncService({required this.client});

  void proposeMessage(String contactId, String content) {
    client.sendRaw({
      'type': 'push.propose',
      'payload': {
        'table': 'messages',
        'operation': 'insert',
        'row': {
          'id': 'pc_${DateTime.now().microsecondsSinceEpoch}',
          'contact_id': contactId,
          'role': 'user',
          'content': content,
          'type': 'text',
          'created_at': DateTime.now().toIso8601String(),
        },
      },
    });
  }
}
