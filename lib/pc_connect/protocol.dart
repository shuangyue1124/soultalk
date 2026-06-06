import 'dart:convert';

class LanSyncEnvelope {
  final int v;
  final String id;
  final String type;
  final String? deviceId;
  final String sentAt;
  final Map<String, dynamic> payload;

  const LanSyncEnvelope({
    required this.v,
    required this.id,
    required this.type,
    required this.deviceId,
    required this.sentAt,
    required this.payload,
  });

  factory LanSyncEnvelope.fromJson(Map<String, dynamic> json) {
    return LanSyncEnvelope(
      v: json['v'] as int? ?? 1,
      id: json['id'] as String? ?? '',
      type: json['type'] as String,
      deviceId: json['deviceId'] as String?,
      sentAt: json['sentAt'] as String? ?? DateTime.now().toIso8601String(),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  factory LanSyncEnvelope.decode(String raw) {
    return LanSyncEnvelope.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() => {
    'v': v,
    'id': id,
    'type': type,
    'deviceId': deviceId,
    'sentAt': sentAt,
    'payload': payload,
  };

  String encode() => jsonEncode(toJson());
}
