import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import 'api_config_provider.dart';

const _kPageSize = 50;

// ─── 消息列表 Provider ────────────────────────────────────────────────────────

class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  int _offset = 0;
  bool _hasMore = true;

  @override
  Future<List<Message>> build(String contactId) async {
    _offset = 0;
    final msgs = await ref
        .read(chatServiceProvider)
        .getMessagePage(contactId, limit: _kPageSize, offset: 0);
    _hasMore = msgs.length == _kPageSize;
    return msgs;
  }

  bool get hasMore => _hasMore;

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final nextOffset = _offset + _kPageSize;
    final older = await ref
        .read(chatServiceProvider)
        .getMessagePage(arg, limit: _kPageSize, offset: nextOffset);
    if (older.isEmpty) {
      _hasMore = false;
      return;
    }
    _offset = nextOffset;
    final current = state.value ?? [];
    state = AsyncData([...older, ...current]);
    _hasMore = older.length == _kPageSize;
  }

  void addMessage(Message message) {
    final current = state.value ?? [];
    state = AsyncData([...current, message]);
  }

  void updateLastMessage(
    String id,
    String content, {
    bool isStreaming = false,
  }) {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(
        content: content,
        isStreaming: isStreaming,
      );
      state = AsyncData(newList);
    }
  }

  void updateLastMessageMetadata(String id, Map<String, dynamic> metadata) {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(metadata: metadata);
      state = AsyncData(newList);
    }
  }

  Future<void> removeMessage(String messageId) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final service = ref.read(chatServiceProvider);
      await service.deleteMessage(messageId);
      final list = previous.value ?? [];
      return list.where((m) => m.id != messageId).toList();
    });
  }

  Future<void> retractMessage(String messageId) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final list = previous.value ?? [];
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx < 0) return list;
      final original = list[idx];
      await ref
          .read(chatServiceProvider)
          .retractMessage(messageId, '[用户撤回了一条消息：${original.content}]');
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(
        type: MessageType.system,
        content: '你撤回了一条消息',
      );
      return newList;
    });
  }

  Future<void> clearMessages() async {
    final contactId = arg;
    state = await AsyncValue.guard(() async {
      await ref.read(chatServiceProvider).deleteMessages(contactId);
      _offset = 0;
      _hasMore = false;
      return <Message>[];
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _offset = 0;
    state = await AsyncValue.guard(() async {
      final msgs = await ref
          .read(chatServiceProvider)
          .getMessagePage(arg, limit: _kPageSize, offset: 0);
      _hasMore = msgs.length == _kPageSize;
      return msgs;
    });
  }
}

final messagesProvider =
    AsyncNotifierProviderFamily<MessagesNotifier, List<Message>, String>(
      MessagesNotifier.new,
    );

// ─── 当前发送状态 ─────────────────────────────────────────────────────────────

final isSendingProvider = StateProvider.family<bool, String>(
  (ref, contactId) => false,
);
