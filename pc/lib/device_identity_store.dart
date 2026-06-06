import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class PcDeviceIdentity {
  final String deviceId;
  final String deviceKey;
  final String deviceName;

  const PcDeviceIdentity({
    required this.deviceId,
    required this.deviceKey,
    required this.deviceName,
  });
}

class DeviceIdentityStore {
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'lansync_pc_device_id';
  static const _deviceKeyKey = 'lansync_pc_device_key';
  static const _deviceNameKey = 'lansync_pc_device_name';

  Future<PcDeviceIdentity> loadOrCreate({
    String defaultName = 'SoulTalk PC',
  }) async {
    var deviceId = await _storage.read(key: _deviceIdKey);
    var deviceKey = await _storage.read(key: _deviceKeyKey);
    var deviceName = await _storage.read(key: _deviceNameKey) ?? defaultName;

    if (deviceId == null || deviceKey == null) {
      deviceId = 'pc_${const Uuid().v4()}';
      deviceKey = _randomKey();
      await _storage.write(key: _deviceIdKey, value: deviceId);
      await _storage.write(key: _deviceKeyKey, value: deviceKey);
      await _storage.write(key: _deviceNameKey, value: deviceName);
    }

    return PcDeviceIdentity(
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
