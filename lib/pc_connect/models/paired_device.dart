class PairedDevice {
  final String deviceId;
  final String deviceName;
  final String deviceKeyHash;
  final int authorizedAt;
  final int lastSeenAt;
  final bool revoked;
  final List<String> permissions;

  const PairedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceKeyHash,
    required this.authorizedAt,
    required this.lastSeenAt,
    required this.revoked,
    required this.permissions,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'deviceKeyHash': deviceKeyHash,
    'authorizedAt': authorizedAt,
    'lastSeenAt': lastSeenAt,
    'revoked': revoked,
    'permissions': permissions,
  };

  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String? ?? 'PC',
      deviceKeyHash: json['deviceKeyHash'] as String,
      authorizedAt: json['authorizedAt'] as int? ?? 0,
      lastSeenAt: json['lastSeenAt'] as int? ?? 0,
      revoked: json['revoked'] as bool? ?? false,
      permissions:
          (json['permissions'] as List?)?.cast<String>() ?? const ['pull'],
    );
  }
}
