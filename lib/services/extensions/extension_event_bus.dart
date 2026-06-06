import 'dart:async';

import '../../models/extension_event.dart';

class ExtensionEventBus {
  static final ExtensionEventBus instance = ExtensionEventBus._();
  ExtensionEventBus._();

  final StreamController<ExtensionEvent> _controller =
      StreamController.broadcast();

  Stream<ExtensionEvent> get events => _controller.stream;

  void publish(ExtensionEvent event) {
    if (!_allowedEvents.contains(event.type)) return;
    _controller.add(event);
  }

  void publishType(
    String type, {
    Map<String, dynamic> payload = const {},
    String? contactId,
    String? messageId,
  }) {
    publish(
      ExtensionEvent(
        type: type,
        payload: payload,
        timestamp: DateTime.now(),
        contactId: contactId,
        messageId: messageId,
      ),
    );
  }

  static const _allowedEvents = {
    'app_ready',
    'chat_opened',
    'message_sent',
    'message_received',
    'message_stream_chunk',
    'generation_started',
    'generation_completed',
    'generation_failed',
    'moment_created',
    'moment_liked',
    'moment_commented',
    'proactive_check_started',
    'proactive_message_sent',
    'context_updated',
  };
}
