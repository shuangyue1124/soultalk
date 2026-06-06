import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentity {
  final String deviceId;
  final String deviceKey;
  final String deviceName;

  const DeviceIdentity({
    required this.deviceId,
    required this.deviceKey,
    required this.deviceName,
  });
}

class DeviceIdentityService {
  static const _deviceIdKey = 'lansync_device_id';
  static const _deviceKeyKey = 'lansync_device_key';
  static const _deviceNameKey = 'lansync_device_name';

  Future<DeviceIdentity> loadOrCreate({
    String defaultName = 'SoulTalk Mobile',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    var deviceKey = prefs.getString(_deviceKeyKey);
    final deviceName = prefs.getString(_deviceNameKey) ?? defaultName;

    if (deviceId == null || deviceKey == null) {
      deviceId = 'mobile_${const Uuid().v4()}';
      deviceKey = _randomKey();
      await prefs.setString(_deviceIdKey, deviceId);
      await prefs.setString(_deviceKeyKey, deviceKey);
      await prefs.setString(_deviceNameKey, deviceName);
    }

    return DeviceIdentity(
      deviceId: deviceId,
      deviceKey: deviceKey,
      deviceName: deviceName,
    );
  }

  String _randomKey() {
    final rng = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => rng.nextInt(256)));
  }
}
