import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../services/database/database_service.dart';

/// 处理消息同步相关逻辑
class SyncHandler {
  final DatabaseService dbService;

  SyncHandler({DatabaseService? dbService})
    : dbService = dbService ?? DatabaseService();

  /// 获取同步数据
  Future<Map<String, dynamic>> getSyncData({
    DateTime? since,
    int limit = 20,
  }) async {
    final db = await dbService.database;
    final where = since == null ? null : 'created_at > ?';
    final whereArgs = since == null ? null : [since.toIso8601String()];
    final messages = await db.query(
      'messages',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    return {
      'messages': messages,
      'serverTime': DateTime.now().toIso8601String(),
      'hasMore': messages.length == limit,
    };
  }

  /// 计算 Merkle Root 用于同步检查
  Future<String> calculateMerkleRoot({DateTime? since}) async {
    // 【推测】实际实现需要计算消息的 Merkle Root
    // 用于快速检测数据是否一致
    final data = await getSyncData(since: since, limit: 1000);
    final messages = data['messages'] as List<dynamic>;

    if (messages.isEmpty) {
      return sha256.convert(utf8.encode('empty')).toString();
    }

    // 计算所有消息的哈希
    final hashes = messages.map((m) {
      final json = jsonEncode(m);
      return sha256.convert(utf8.encode(json)).toString();
    }).toList();

    // 简化的 Merkle Root 计算
    return _calculateMerkleRoot(hashes);
  }

  String _calculateMerkleRoot(List<String> hashes) {
    if (hashes.isEmpty) {
      return sha256.convert(utf8.encode('')).toString();
    }

    if (hashes.length == 1) {
      return hashes.first;
    }

    final nextLevel = <String>[];
    for (var i = 0; i < hashes.length; i += 2) {
      if (i + 1 < hashes.length) {
        final combined = hashes[i] + hashes[i + 1];
        nextLevel.add(sha256.convert(utf8.encode(combined)).toString());
      } else {
        nextLevel.add(hashes[i]);
      }
    }

    return _calculateMerkleRoot(nextLevel);
  }

  /// 应用冲突解决方案
  Future<void> applyResolutions(List<dynamic> resolutions) async {
    for (final resolution in resolutions) {
      final action = resolution['action'] as String;
      final messageId = resolution['messageId'] as String?;
      final content = resolution['content'] as String?;

      switch (action) {
        case 'keep_mobile':
          // 保留手机版，不做操作
          break;
        case 'keep_pc':
          // 用电脑版替换手机版
          if (messageId != null && content != null) {
            await _replaceMessage(messageId, content);
          }
          break;
        case 'manual_edit':
          // 用手动编辑的内容覆盖
          if (messageId != null && content != null) {
            await _replaceMessage(messageId, content);
          }
          break;
      }
    }
  }

  Future<void> _replaceMessage(String messageId, String content) async {
    final db = await dbService.database;
    await db.update(
      'messages',
      {'content': content},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
}
