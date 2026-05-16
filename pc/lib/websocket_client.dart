import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

/// PC 端 WebSocket 客户端，连接手机端
class WebSocketClient {
  WebSocketChannel? _channel;
  // ignore: unused_field — kept for future use
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  String? _deviceId;
  String? _serverUrl;
  bool _isAuthenticated = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  bool get isConnected => _channel != null && _isAuthenticated;
  String? get deviceId => _deviceId;
  WsConnectionState _currentState = WsConnectionState.disconnected;

  /// 连接到手机端 WebSocket 服务器
  Future<void> connect(String url) async {
    if (_disposed) return;
    if (_channel != null) {
      await disconnect();
    }

    _serverUrl = url;
    _currentState = WsConnectionState.connecting;
    _emitState();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
      );

      // 发送认证消息
      _sendAuth();
    } catch (e) {
      _onError(e);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      if (!_disposed) {
        _sendMessage({'type': 'disconnect'});
      }
      await channel.sink.close();
    }

    _isAuthenticated = false;
    _deviceId = null;
    _currentState = WsConnectionState.disconnected;
    _emitState();
  }

  /// 请求同步消息
  void requestSync({String? since, int limit = 20}) {
    _sendMessage({'type': 'sync', 'since': since, 'limit': limit});
  }

  /// 发送新消息
  void sendMessage(String contactId, String content) {
    _sendMessage({
      'type': 'new_message',
      'contactId': contactId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 发送冲突解决方案
  void sendConflictResolution(List<Map<String, dynamic>> resolutions) {
    _sendMessage({'type': 'conflict_resolved', 'resolutions': resolutions});
  }

  /// 发送同步检查
  void sendSyncCheck(String lastSyncTime) {
    _sendMessage({'type': 'sync_check', 'lastSyncTime': lastSyncTime});
  }

  void _sendAuth() {
    final uuid = const Uuid();
    _sendMessage({
      'type': 'auth',
      'deviceName': 'PC-${uuid.v4().substring(0, 8)}',
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      _onError(e);
    }
  }

  void _onMessage(dynamic rawMessage) {
    try {
      final message = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'auth_ok':
          _handleAuthOk(message);
          break;
        case 'auth_error':
          _handleAuthError(message);
          break;
        case 'sync_data':
        case 'sync_check_result':
        case 'sync_ready':
        case 'new_message':
        case 'api_config':
        case 'api_config_disabled':
        case 'clear_api':
        case 'disconnect':
        case 'pong':
        case 'error':
          _emitEvent(message);
          break;
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  void _handleAuthOk(Map<String, dynamic> message) {
    _deviceId = message['deviceId'] as String?;
    _isAuthenticated = true;
    _reconnectAttempts = 0;
    _currentState = WsConnectionState.connected;
    _emitState();

    _startHeartbeat();
    _emitEvent(message);
  }

  void _handleAuthError(Map<String, dynamic> message) {
    _isAuthenticated = false;
    _currentState = WsConnectionState.authFailed;
    _emitState();
    _emitEvent(message);
  }

  void _onDisconnected() {
    _heartbeatTimer?.cancel();
    _channel = null;
    _isAuthenticated = false;

    if (_currentState == WsConnectionState.connected) {
      _currentState = WsConnectionState.disconnected;
      _emitState();
      _tryReconnect();
    }
  }

  void _onError(dynamic error) {
    if (_currentState != WsConnectionState.connected) {
      _currentState = WsConnectionState.failed;
      _emitState();
    }
    _emitEvent({'type': 'error', 'message': error.toString()});
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      _sendMessage({'type': 'ping'});
    });
  }

  void _tryReconnect() {
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _currentState = WsConnectionState.failed;
      _emitState();
      return;
    }

    _reconnectAttempts++;
    _currentState = WsConnectionState.reconnecting;
    _emitState();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_disposed && _serverUrl != null) {
        connect(_serverUrl!);
      }
    });
  }

  void _emitState() {
    if (!_disposed && !_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  void _emitEvent(Map<String, dynamic> event) {
    if (!_disposed && !_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventController.close();
    await _stateController.close();
  }
}

/// WebSocket 连接状态
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  authFailed,
  reconnecting,
  failed,
}
