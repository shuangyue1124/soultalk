import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'websocket_client.dart';
import 'sync/pull_sync_service.dart';
import 'sync/push_sync_service.dart';
import 'services/database/pc_mirror_dao.dart';

/// 同步管理器 - 处理与手机端的消息同步
class SyncManager {
  final WebSocketClient _client;
  late final PullSyncService _pullSyncService;
  late final PushSyncService _pushSyncService;
  final PcMirrorDao _mirrorDao;
  final List<Map<String, dynamic>> _messages = [];
  String? _lastSyncTime;

  final StreamController<List<Map<String, dynamic>>> _messagesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();

  Stream<List<Map<String, dynamic>>> get messagesStream =>
      _messagesController.stream;
  Stream<SyncState> get stateStream => _stateController.stream;

  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  String? get lastSyncTime => _lastSyncTime;

  SyncManager(this._client, {PcMirrorDao? mirrorDao})
    : _mirrorDao = mirrorDao ?? PcMirrorDao() {
    _pullSyncService = PullSyncService(client: _client, mirrorDao: _mirrorDao);
    _pushSyncService = PushSyncService(client: _client);
    _client.events.listen(_handleEvent);
  }

  /// 请求同步
  void requestSync() {
    _stateController.add(SyncState.syncing);
    _pullSyncService.requestManifest();
    _pullSyncService.requestTable('messages');
  }

  /// 检查同步状态
  void checkSync() {
    if (_lastSyncTime != null) {
      _client.sendSyncCheck(_lastSyncTime!);
    }
  }

  /// 发送新消息
  void sendMessage(String contactId, String content) {
    _pushSyncService.proposeMessage(contactId, content);

    // 本地添加消息
    final message = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'contactId': contactId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'fromPC': true,
    };
    _messages.add(message);
    _messagesController.add(_messages);
  }

  /// 解决冲突
  void resolveConflicts(List<Map<String, dynamic>> resolutions) {
    _client.sendConflictResolution(resolutions);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    switch (type) {
      case 'sync_data':
        _handleSyncData(event);
        break;
      case 'sync_check_result':
        _handleSyncCheckResult(event);
        break;
      case 'new_message':
        _handleNewMessage(event);
        break;
      case 'manifest.response':
        _stateController.add(SyncState.syncing);
        break;
      case 'pull.chunk':
        _handlePullChunk(event);
        break;
      case 'pull.complete':
        _stateController.add(SyncState.idle);
        break;
      case 'push.result':
        if (((event['payload'] as Map?)?['accepted'] as bool?) == false) {
          _stateController.add(SyncState.error);
        }
        break;
    }
  }

  void _handleSyncData(Map<String, dynamic> event) {
    final data = event['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final messages = data['messages'] as List<dynamic>?;
    if (messages != null) {
      for (final msg in messages) {
        final msgMap = msg as Map<String, dynamic>;
        // 避免重复
        if (!_messages.any((m) => m['id'] == msgMap['id'])) {
          _messages.add(msgMap);
        }
      }
      // 按时间排序
      _messages.sort((a, b) {
        final aTime = a['timestamp'] as String? ?? '';
        final bTime = b['timestamp'] as String? ?? '';
        return aTime.compareTo(bTime);
      });
      _messagesController.add(_messages);
    }

    _lastSyncTime =
        data['serverTime'] as String? ?? DateTime.now().toIso8601String();
    _stateController.add(SyncState.idle);
  }

  Future<void> _handlePullChunk(Map<String, dynamic> event) async {
    await _pullSyncService.handlePullChunk(event);
    final rows = await _mirrorDao.getRows('messages');
    _messages
      ..clear()
      ..addAll(rows);
    _messagesController.add(_messages);
  }

  void _handleSyncCheckResult(Map<String, dynamic> event) {
    final serverMerkleRoot = event['merkleRoot'] as String?;
    final localMerkleRoot = _calculateLocalMerkleRoot();

    if (serverMerkleRoot != localMerkleRoot) {
      // 数据不一致，需要同步
      requestSync();
    } else {
      _stateController.add(SyncState.idle);
    }
  }

  void _handleNewMessage(Map<String, dynamic> event) {
    final message = {
      'id':
          event['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'contactId': event['contactId'],
      'content': event['content'],
      'timestamp': event['timestamp'],
      'fromPC': event['fromPC'] ?? false,
    };

    if (!_messages.any((m) => m['id'] == message['id'])) {
      _messages.add(message);
      _messagesController.add(_messages);
    }
  }

  String _calculateLocalMerkleRoot() {
    if (_messages.isEmpty) {
      return sha256.convert(utf8.encode('empty')).toString();
    }

    final hashes = _messages.map((m) {
      final json = jsonEncode(m);
      return sha256.convert(utf8.encode(json)).toString();
    }).toList();

    return _calculateMerkle(hashes);
  }

  String _calculateMerkle(List<String> hashes) {
    if (hashes.isEmpty) {
      return sha256.convert(utf8.encode('')).toString();
    }
    if (hashes.length == 1) return hashes.first;

    final nextLevel = <String>[];
    for (var i = 0; i < hashes.length; i += 2) {
      if (i + 1 < hashes.length) {
        final combined = hashes[i] + hashes[i + 1];
        nextLevel.add(sha256.convert(utf8.encode(combined)).toString());
      } else {
        nextLevel.add(hashes[i]);
      }
    }
    return _calculateMerkle(nextLevel);
  }

  void dispose() {
    _messagesController.close();
    _stateController.close();
  }
}

enum SyncState { idle, syncing, conflict, error }
