import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

import 'connection_manager.dart';
import 'sync_handler.dart';
import 'api_config_sender.dart';

/// WebSocket 服务端，用于手机端与 PC 端通信
class WebSocketServer {
  static const int _minPort = 49152;
  static const int _maxPort = 65535;
  static const int _maxDevices = 3;
  static const Duration _tokenTtl = Duration(minutes: 2);
  static const Duration _idleTimeout = Duration(minutes: 5);

  HttpServer? _server;
  String? _jwtSecret;
  String? _currentToken;
  Timer? _idleTimer;

  final _uuid = const Uuid();
  final ConnectionManager _connectionManager = ConnectionManager();
  final SyncHandler _syncHandler = SyncHandler();
  final ApiConfigSender _apiConfigSender = ApiConfigSender();

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  ConnectionManager get connectionManager => _connectionManager;

  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String? get currentToken => _currentToken;

  /// 启动 WebSocket 服务器
  Future<int> start() async {
    if (_server != null) {
      throw StateError('Server already running');
    }

    // 生成 JWT 密钥
    _jwtSecret = _generateSecret();
    _refreshToken();

    final handler = shelf.Pipeline()
        .addMiddleware(_checkAuth())
        .addHandler(webSocketHandler(_handleConnection));

    // 带重试的端口绑定
    final rng = Random.secure();
    const maxRetries = 20;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final port = _minPort + rng.nextInt(_maxPort - _minPort + 1);
      try {
        _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
        _startIdleTimer();
        _eventController.add({'type': 'server_started', 'port': port});
        return port;
      } on SocketException {
        if (attempt == maxRetries - 1) rethrow;
        continue;
      }
    }
    throw StateError('Failed to bind to any port after $maxRetries attempts');
  }

  /// 停止服务器
  Future<void> stop() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    // 通知所有连接的 PC
    for (final device in _connectionManager.connectedDevices) {
      _connectionManager.sendMessage(device.deviceId, {
        'type': 'disconnect',
        'reason': 'server_shutdown',
      });
    }

    await _server?.close(force: true);
    _server = null;
    _currentToken = null;
    _connectionManager.clear();

    _eventController.add({'type': 'server_stopped'});
  }

  /// 刷新 JWT token
  String refreshToken() {
    _refreshToken();
    return _currentToken!;
  }

  /// 获取连接 URI
  String getConnectionUri(String localIp) {
    return 'ws://$localIp:${_server?.port}/ws?token=$_currentToken&version=1';
  }

  void _refreshToken() {
    _jwtSecret = _generateSecret();
    final jwt = JWT({
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(_tokenTtl).millisecondsSinceEpoch ~/ 1000,
    });
    _currentToken = jwt.sign(SecretKey(_jwtSecret!));
  }

  String _generateSecret() {
    final rng = Random.secure();
    final random = List.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(random);
  }

  shelf.Middleware _checkAuth() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) {
        // 只检查 WebSocket 连接
        if (request.url.path == 'ws') {
          final token = request.url.queryParameters['token'];
          if (token == null || !_validateToken(token)) {
            return shelf.Response.forbidden('Invalid or expired token');
          }

          // 检查是否超过最大设备数
          if (_connectionManager.connectedDevices.length >= _maxDevices) {
            return shelf.Response.forbidden('Maximum devices reached');
          }

          // 检查是否内网 IP
          final clientIp = _getClientIp(request);
          if (clientIp == null || !_isPrivateIp(clientIp)) {
            return shelf.Response.forbidden('Only LAN connections allowed');
          }
        }
        return innerHandler(request);
      };
    };
  }

  /// 获取客户端 IP 地址
  String? _getClientIp(shelf.Request request) {
    // 优先检查 X-Forwarded-For 头（代理场景）
    final forwardedFor = request.headers['x-forwarded-for'];
    if (forwardedFor != null) {
      // 取第一个 IP（最初的客户端 IP）
      return forwardedFor.split(',').first.trim();
    }

    // 检查 X-Real-IP 头
    final realIp = request.headers['x-real-ip'];
    if (realIp != null) {
      return realIp;
    }

    // 【推测】shelf 的 Request 没有直接获取 remoteAddr 的方法
    // 需要通过 HttpServer 的 connectionInfo 获取
    // 这里返回 null，由调用方处理
    return null;
  }

  /// 检查是否为内网 IP 地址
  bool _isPrivateIp(String ip) {
    try {
      final addr = InternetAddress(ip);
      // IPv4 内网地址范围
      if (addr.type == InternetAddressType.IPv4) {
        final parts = ip.split('.').map(int.parse).toList();
        if (parts.length != 4) return false;

        // 10.0.0.0/8
        if (parts[0] == 10) return true;
        // 172.16.0.0/12
        if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
        // 192.168.0.0/16
        if (parts[0] == 192 && parts[1] == 168) return true;
        // 127.0.0.0/8 (localhost)
        if (parts[0] == 127) return true;

        return false;
      }

      // IPv6 内网地址
      if (addr.type == InternetAddressType.IPv6) {
        // ::1 (localhost)
        if (ip == '::1') return true;
        // fe80::/10 (link-local)
        if (ip.startsWith('fe80:')) return true;
        // fc00::/7 (unique local)
        if (ip.startsWith('fc') || ip.startsWith('fd')) return true;

        return false;
      }

      return false;
    } catch (e) {
      // IP 解析失败，默认拒绝
      return false;
    }
  }

  void _handleConnection(WebSocketChannel webSocket, String? protocol) {
    final deviceId = _generateDeviceId();

    webSocket.stream.listen(
      (message) {
        _resetIdleTimer();
        _handleMessage(deviceId, message as String);
      },
      onDone: () {
        _connectionManager.removeDevice(deviceId);
        _eventController.add({
          'type': 'device_disconnected',
          'deviceId': deviceId,
        });
      },
      onError: (error) {
        _connectionManager.removeDevice(deviceId);
      },
    );

    _connectionManager.addDevice(deviceId, webSocket);

    _eventController.add({'type': 'device_connected', 'deviceId': deviceId});
  }

  void _handleMessage(String deviceId, String rawMessage) {
    try {
      final message = jsonDecode(rawMessage) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'auth':
          _handleAuth(deviceId, message);
          break;
        case 'sync':
          _handleSync(deviceId, message);
          break;
        case 'sync_check':
          _handleSyncCheck(deviceId, message);
          break;
        case 'new_message':
          _handleNewMessage(deviceId, message);
          break;
        case 'conflict_resolved':
          _handleConflictResolved(deviceId, message);
          break;
        case 'disconnect':
          _handleDisconnect(deviceId, message);
          break;
        case 'ping':
          _connectionManager.sendMessage(deviceId, {'type': 'pong'});
          break;
        default:
          _connectionManager.sendMessage(deviceId, {
            'type': 'error',
            'message': 'Unknown message type: $type',
          });
      }
    } catch (e) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'error',
        'message': 'Invalid message format',
      });
    }
  }

  void _handleAuth(String deviceId, Map<String, dynamic> message) {
    final deviceName = message['deviceName'] as String? ?? 'PC';
    _connectionManager.setDeviceName(deviceId, deviceName);

    _connectionManager.sendMessage(deviceId, {
      'type': 'auth_ok',
      'deviceId': deviceId,
      'serverTime': DateTime.now().toIso8601String(),
    });

    // 发送 API 配置
    _apiConfigSender.sendConfig(deviceId, _connectionManager);

    _eventController.add({
      'type': 'device_authenticated',
      'deviceId': deviceId,
      'deviceName': deviceName,
    });
  }

  Future<void> _handleSync(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    final since = message['since'] as String?;
    final limit = message['limit'] as int? ?? 20;

    final data = await _syncHandler.getSyncData(
      since: since != null ? DateTime.tryParse(since) : null,
      limit: limit,
    );

    _connectionManager.sendMessage(deviceId, {
      'type': 'sync_data',
      'data': data,
    });
  }

  Future<void> _handleSyncCheck(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    final lastSyncTime = message['lastSyncTime'] as String?;
    if (lastSyncTime == null) return;

    final merkleRoot = await _syncHandler.calculateMerkleRoot(
      since: DateTime.tryParse(lastSyncTime),
    );

    _connectionManager.sendMessage(deviceId, {
      'type': 'sync_check_result',
      'merkleRoot': merkleRoot,
      'serverTime': DateTime.now().toIso8601String(),
    });
  }

  void _handleNewMessage(String deviceId, Map<String, dynamic> message) {
    // 标记来自 PC
    message['fromPC'] = true;
    message['fromDevice'] = deviceId;

    // 广播给其他连接的设备
    for (final device in _connectionManager.connectedDevices) {
      if (device.deviceId != deviceId) {
        _connectionManager.sendMessage(device.deviceId, message);
      }
    }

    _eventController.add({'type': 'new_message', 'message': message});
  }

  Future<void> _handleConflictResolved(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    final resolutions = message['resolutions'] as List<dynamic>?;
    if (resolutions == null) return;

    await _syncHandler.applyResolutions(resolutions);

    // 通知 PC 同步就绪
    _connectionManager.sendMessage(deviceId, {'type': 'sync_ready'});
  }

  void _handleDisconnect(String deviceId, Map<String, dynamic> message) {
    final keepPCAlive = message['keepPCAlive'] as bool? ?? false;
    _connectionManager.removeDevice(deviceId);

    _eventController.add({
      'type': 'device_disconnected',
      'deviceId': deviceId,
      'keepPCAlive': keepPCAlive,
    });
  }

  bool _validateToken(String token) {
    try {
      JWT.verify(token, SecretKey(_jwtSecret!));
      return true;
    } catch (e) {
      return false;
    }
  }

  String _generateDeviceId() {
    return 'pc_${_uuid.v4()}';
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (_connectionManager.connectedDevices.isEmpty) {
        stop();
        _eventController.add({'type': 'idle_shutdown'});
      }
    });
  }

  void _resetIdleTimer() {
    _startIdleTimer();
  }

  void dispose() {
    stop();
    _eventController.close();
  }
}
