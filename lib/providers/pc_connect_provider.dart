import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pc_connect/websocket_server.dart';
import '../pc_connect/models/pc_device.dart';

/// 配对状态
enum PairingState { idle, scanning, pairing, success, failed }

/// PC 连接状态
class PcConnectState {
  final bool isEnabled;
  final bool isServerRunning;
  final int? port;
  final String? localIp;
  final String? qrData;
  final List<PcDevice> connectedDevices;
  final bool allowPCUseApi;
  final bool keepPCReadOnly;
  final PairingState pairingState;

  const PcConnectState({
    this.isEnabled = false,
    this.isServerRunning = false,
    this.port,
    this.localIp,
    this.qrData,
    this.connectedDevices = const [],
    this.allowPCUseApi = true,
    this.keepPCReadOnly = true,
    this.pairingState = PairingState.idle,
  });

  PcConnectState copyWith({
    bool? isEnabled,
    bool? isServerRunning,
    int? port,
    String? localIp,
    String? qrData,
    List<PcDevice>? connectedDevices,
    bool? allowPCUseApi,
    bool? keepPCReadOnly,
    PairingState? pairingState,
  }) {
    return PcConnectState(
      isEnabled: isEnabled ?? this.isEnabled,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      port: port ?? this.port,
      localIp: localIp ?? this.localIp,
      qrData: qrData ?? this.qrData,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      allowPCUseApi: allowPCUseApi ?? this.allowPCUseApi,
      keepPCReadOnly: keepPCReadOnly ?? this.keepPCReadOnly,
      pairingState: pairingState ?? this.pairingState,
    );
  }
}

/// PC 连接管理 Provider
class PcConnectNotifier extends StateNotifier<PcConnectState> {
  final WebSocketServer _server = WebSocketServer();
  StreamSubscription? _eventSubscription;

  PcConnectNotifier() : super(const PcConnectState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      allowPCUseApi: prefs.getBool('pc_allow_api') ?? true,
      keepPCReadOnly: prefs.getBool('pc_keep_readonly') ?? true,
    );
  }

  /// 启用/禁用 PC 连接
  Future<void> toggleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pc_connect_enabled', enabled);

    if (enabled) {
      await startServer();
    } else {
      await stopServer();
    }

    state = state.copyWith(isEnabled: enabled);
  }

  /// 启动 WebSocket 服务器
  Future<void> startServer() async {
    if (_server.isRunning) return;

    try {
      final port = await _server.start();
      final ip = await _getLocalIp();

      _eventSubscription = _server.events.listen(_handleEvent);

      state = state.copyWith(
        isServerRunning: true,
        port: port,
        localIp: ip,
        qrData: _server.getConnectionUri(ip ?? '0.0.0.0'),
      );
    } catch (e) {
      state = state.copyWith(isServerRunning: false);
    }
  }

  /// 完成配对：扫描 PC 二维码后，启动服务器并将 WS URI 发送给 PC
  Future<bool> completePairing(String pairingUrl) async {
    if (state.pairingState == PairingState.pairing) return false;

    state = state.copyWith(pairingState: PairingState.pairing);

    // 如果服务器未运行，先启动
    if (!_server.isRunning) {
      await startServer();
    }

    if (!_server.isRunning) {
      state = state.copyWith(pairingState: PairingState.failed);
      return false;
    }

    final wsUri = _server.getConnectionUri(state.localIp ?? '0.0.0.0');

    try {
      final uri = Uri.parse(pairingUrl);
      final client = HttpClient();
      try {
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'ws_uri': wsUri}));
        final response = await request.close();

        if (response.statusCode == 200) {
          state = state.copyWith(pairingState: PairingState.success);
          return true;
        } else {
          state = state.copyWith(pairingState: PairingState.failed);
          return false;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      state = state.copyWith(pairingState: PairingState.failed);
      return false;
    }
  }

  /// 停止服务器
  Future<void> stopServer() async {
    await _server.stop();
    _eventSubscription?.cancel();

    state = state.copyWith(
      isServerRunning: false,
      port: null,
      qrData: null,
      connectedDevices: [],
    );
  }

  /// 刷新二维码（旧逻辑保留，用于手动模式）
  void refreshQRCode() {
    if (!_server.isRunning) return;

    _server.refreshToken();
    state = state.copyWith(
      qrData: _server.getConnectionUri(state.localIp ?? '0.0.0.0'),
    );
  }

  /// 断开指定设备
  void disconnectDevice(String deviceId) {
    _server.connectionManager.removeDevice(deviceId);
    _updateConnectedDevices();
  }

  /// 断开所有设备
  void disconnectAllDevices() {
    _server.connectionManager.clear();
    _updateConnectedDevices();
  }

  /// 设置是否允许 PC 使用 API
  Future<void> setAllowPCUseApi(bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pc_allow_api', allow);
    state = state.copyWith(allowPCUseApi: allow);
  }

  /// 设置是否保持 PC 只读模式
  Future<void> setKeepPCReadOnly(bool keep) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pc_keep_readonly', keep);
    state = state.copyWith(keepPCReadOnly: keep);
  }

  /// 重置配对状态
  void resetPairingState() {
    state = state.copyWith(pairingState: PairingState.idle);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    switch (type) {
      case 'device_connected':
      case 'device_authenticated':
      case 'device_disconnected':
        _updateConnectedDevices();
        break;
      case 'idle_shutdown':
        state = state.copyWith(
          isServerRunning: false,
          port: null,
          qrData: null,
        );
        break;
    }
  }

  void _updateConnectedDevices() {
    state = state.copyWith(
      connectedDevices: _server.connectionManager.connectedDevices,
    );
  }

  Future<String?> _getLocalIp() async {
    try {
      final networkInfo = NetworkInfo();
      return await networkInfo.getWifiIP();
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _server.dispose();
    super.dispose();
  }
}

final pcConnectProvider =
    StateNotifierProvider<PcConnectNotifier, PcConnectState>((ref) {
      return PcConnectNotifier();
    });
