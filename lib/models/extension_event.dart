class ExtensionEvent {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final String source;
  final String? contactId;
  final String? messageId;

  const ExtensionEvent({
    required this.type,
    required this.payload,
    required this.timestamp,
    this.source = 'soultalk',
    this.contactId,
    this.messageId,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'contactId': contactId,
    'messageId': messageId,
  };
}
