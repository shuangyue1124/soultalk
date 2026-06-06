import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/paired_device.dart';

class PairingStore {
  static const _devicesKey = 'lansync_paired_devices';

  Future<List<PairedDevice>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_devicesKey) ?? const [];
    return raw
        .map(
          (item) =>
              PairedDevice.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<PairedDevice?> getDevice(String deviceId) async {
    final devices = await loadDevices();
    for (final device in devices) {
      if (device.deviceId == deviceId) return device;
    }
    return null;
  }

  Future<PairedDevice> approve({
    required String deviceId,
    required String deviceName,
    required String deviceKey,
    List<String> permissions = const ['pull'],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final device = PairedDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceKeyHash: sha256.convert(utf8.encode(deviceKey)).toString(),
      authorizedAt: now,
      lastSeenAt: now,
      revoked: false,
      permissions: permissions,
    );
    final devices = (await loadDevices())
        .where((item) => item.deviceId != deviceId)
        .toList();
    devices.add(device);
    await _save(devices);
    return device;
  }

  Future<void> revoke(String deviceId) async {
    final devices = await loadDevices();
    await _save([
      for (final device in devices)
        if (device.deviceId == deviceId)
          PairedDevice(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            deviceKeyHash: device.deviceKeyHash,
            authorizedAt: device.authorizedAt,
            lastSeenAt: device.lastSeenAt,
            revoked: true,
            permissions: device.permissions,
          )
        else
          device,
    ]);
  }

  Future<bool> verify(String deviceId, String deviceKey) async {
    final device = await getDevice(deviceId);
    if (device == null || device.revoked) return false;
    return device.deviceKeyHash ==
        sha256.convert(utf8.encode(deviceKey)).toString();
  }

  Future<void> _save(List<PairedDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _devicesKey,
      devices.map((device) => jsonEncode(device.toJson())).toList(),
    );
  }
}
