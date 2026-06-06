import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../websocket_client.dart';
import '../sync_manager.dart';
import '../api_config_manager.dart';

/// 连接状态
class PCConnectionState {
  final WsConnectionState connectionState;
  final String? deviceId;
  final String? serverUrl;
  final List<Map<String, dynamic>> messages;
  final ApiConfigMode apiMode;
  final ApiConfig? activeApiConfig;
  final String? error;
  final String? pairingQrData;
  final bool isPairingServerRunning;

  const PCConnectionState({
    this.connectionState = WsConnectionState.disconnected,
    this.deviceId,
    this.serverUrl,
    this.messages = const [],
    this.apiMode = ApiConfigMode.followPhone,
    this.activeApiConfig,
    this.error,
    this.pairingQrData,
    this.isPairingServerRunning = false,
  });

  PCConnectionState copyWith({
    WsConnectionState? connectionState,
    String? deviceId,
    String? serverUrl,
    List<Map<String, dynamic>>? messages,
    ApiConfigMode? apiMode,
    ApiConfig? activeApiConfig,
    String? error,
    String? pairingQrData,
    bool? isPairingServerRunning,
  }) {
    return PCConnectionState(
      connectionState: connectionState ?? this.connectionState,
      deviceId: deviceId ?? this.deviceId,
      serverUrl: serverUrl ?? this.serverUrl,
      messages: messages ?? this.messages,
      apiMode: apiMode ?? this.apiMode,
      activeApiConfig: activeApiConfig ?? this.activeApiConfig,
      error: error,
      pairingQrData: pairingQrData ?? this.pairingQrData,
      isPairingServerRunning:
          isPairingServerRunning ?? this.isPairingServerRunning,
    );
  }
}

/// 连接管理 Provider
class PCConnectionNotifier extends StateNotifier<PCConnectionState> {
  final WebSocketClient _client = WebSocketClient();
  final ApiConfigManager _configManager = ApiConfigManager();
  SyncManager? _syncManager;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _messagesSubscription;

  HttpServer? _pairingServer;
  String? _pairingCode;

  PCConnectionNotifier() : super(const PCConnectionState()) {
    _init();
  }

  Future<void> _init() async {
    await _configManager.init();

    _stateSubscription = _client.stateStream.listen((connectionState) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        connectionState: connectionState,
        deviceId: _client.deviceId,
      );
    });

    _eventSubscription = _client.events.listen(_handleEvent);

    if (!mounted) {
      return;
    }
    state = state.copyWith(
      apiMode: _configManager.mode,
      activeApiConfig: _configManager.activeConfig,
    );
  }

  /// 启动配对服务器，返回二维码数据
  Future<String> startPairingServer() async {
    _pairingCode = _generatePairingCode();
    final rng = Random.secure();

    const minPort = 49152;
    const maxPort = 65535;
    const maxRetries = 20;

    for (int i = 0; i < maxRetries; i++) {
      final port = minPort + rng.nextInt(maxPort - minPort + 1);
      try {
        _pairingServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
        break;
      } on SocketException {
        if (i == maxRetries - 1) rethrow;
      }
    }

    if (_pairingServer == null) {
      throw StateError('Failed to bind pairing server');
    }

    // 获取本机 IP
    String? ip;
    try {
      ip = await NetworkInfo().getWifiIP();
    } catch (_) {}
    ip ??= '127.0.0.1';

    final pairingUrl =
        'http://$ip:${_pairingServer!.port}/pair?code=$_pairingCode';

    // 监听配对请求
    _pairingServer!.listen(_handlePairingRequest);

    state = state.copyWith(
      pairingQrData: pairingUrl,
      isPairingServerRunning: true,
      error: null,
    );

    return pairingUrl;
  }

  Future<void> _handlePairingRequest(HttpRequest request) async {
    if (request.uri.path != '/pair' || request.method != 'POST') {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }

    final code = request.uri.queryParameters['code'];
    if (code != _pairingCode) {
      request.response.statusCode = 403;
      request.response.write('Invalid pairing code');
      await request.response.close();
      return;
    }

    try {
      final body = await utf8.decodeStream(request);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final wsUri = json['ws_uri'] as String?;

      if (wsUri == null || !wsUri.startsWith('ws://')) {
        request.response.statusCode = 400;
        request.response.write('Invalid ws_uri');
        await request.response.close();
        return;
      }

      // 成功响应
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok'}));
      await request.response.close();

      // 停止配对服务器
      await _stopPairingServer();

      // 连接手机
      await connect(wsUri);
    } catch (e) {
      request.response.statusCode = 400;
      request.response.write('Bad request');
      await request.response.close();
    }
  }

  Future<void> _stopPairingServer({bool updateState = true}) async {
    await _pairingServer?.close(force: true);
    _pairingServer = null;
    _pairingCode = null;
    if (updateState && mounted) {
      state = state.copyWith(isPairingServerRunning: false);
    }
  }

  /// 连接到手机
  Future<void> connect(String url) async {
    state = state.copyWith(serverUrl: url, error: null);
    await _client.connect(url);

    _syncManager = SyncManager(_client);
    _messagesSubscription = _syncManager!.messagesStream.listen((messages) {
      state = state.copyWith(messages: messages);
    });
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _client.disconnect();
    _syncManager?.dispose();
    _syncManager = null;
    state = state.copyWith(
      connectionState: WsConnectionState.disconnected,
      deviceId: null,
      messages: [],
    );
  }

  /// 请求同步
  void requestSync() {
    _syncManager?.requestSync();
  }

  /// 发送消息
  void sendMessage(String contactId, String content) {
    _syncManager?.sendMessage(contactId, content);
  }

  /// 切换 API 模式
  Future<void> switchApiMode(ApiConfigMode mode) async {
    await _configManager.switchMode(mode);
    state = state.copyWith(
      apiMode: mode,
      activeApiConfig: _configManager.activeConfig,
    );
  }

  /// 添加本地 API 配置
  Future<void> addLocalConfig(ApiConfig config) async {
    await _configManager.addLocalConfig(config);
    state = state.copyWith(activeApiConfig: _configManager.activeConfig);
  }

  /// 删除本地 API 配置
  Future<void> removeLocalConfig(String id) async {
    await _configManager.removeLocalConfig(id);
    state = state.copyWith(activeApiConfig: _configManager.activeConfig);
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (!mounted) {
      return;
    }
    final type = event['type'] as String?;

    switch (type) {
      case 'api_config':
        final configs = event['configs'] as List<dynamic>?;
        if (configs != null) {
          final apiConfigs = configs
              .map((c) => ApiConfig.fromJson(c as Map<String, dynamic>))
              .toList();
          _configManager.receiveRemoteConfigs(apiConfigs);
          if (state.apiMode == ApiConfigMode.followPhone) {
            state = state.copyWith(
              activeApiConfig: _configManager.activeConfig,
            );
          }
        }
        break;

      case 'api_config_disabled':
        _configManager.clearRemoteConfigs();
        state = state.copyWith(error: '手机已禁用 API 共享');
        break;

      case 'clear_api':
        _configManager.clearAllRemoteConfigs();
        state = state.copyWith(activeApiConfig: _configManager.activeConfig);
        break;

      case 'error':
        state = state.copyWith(error: event['message'] as String?);
        break;
    }
  }

  static String _generatePairingCode() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _messagesSubscription?.cancel();
    _client.dispose();
    _syncManager?.dispose();
    _stopPairingServer(updateState: false);
    super.dispose();
  }
}

final pcConnectionProvider =
    StateNotifierProvider<PCConnectionNotifier, PCConnectionState>((ref) {
      return PCConnectionNotifier();
    });
