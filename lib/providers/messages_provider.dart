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
    _hasMore = true;
    final msgs = await ref.read(chatServiceProvider).getMessages(contactId);
    // Load last page only, track if there are more
    if (msgs.length > _kPageSize) {
      _hasMore = true;
      return msgs.sublist(msgs.length - _kPageSize);
    }
    _hasMore = false;
    return msgs;
  }

  bool get hasMore => _hasMore;

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final all = await ref.read(chatServiceProvider).getMessages(arg);
    final startIdx = (all.length - _kPageSize - (_offset + 1) * _kPageSize)
        .clamp(0, all.length);
    final endIdx = all.length - _kPageSize - _offset * _kPageSize;
    if (endIdx <= 0 || startIdx >= endIdx) {
      _hasMore = false;
      return;
    }
    _offset++;
    final older = all.sublist(startIdx, endIdx);
    final current = state.value ?? [];
    state = AsyncData([...older, ...current]);
    if (startIdx == 0) _hasMore = false;
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
    final service = ref.read(chatServiceProvider);
    await service.deleteMessage(messageId);
    final list = state.value ?? [];
    state = AsyncData(list.where((m) => m.id != messageId).toList());
  }

  Future<void> retractMessage(String messageId) async {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      final original = list[idx];
      await ref
          .read(chatServiceProvider)
          .retractMessage(messageId, '[用户撤回了一条消息：${original.content}]');
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(
        type: MessageType.system,
        content: '你撤回了一条消息',
      );
      state = AsyncData(newList);
    }
  }

  Future<void> clearMessages() async {
    final contactId = arg;
    await ref.read(chatServiceProvider).deleteMessages(contactId);
    state = const AsyncData([]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _offset = 0;
    _hasMore = true;
    state = await AsyncValue.guard(
      () => ref.read(chatServiceProvider).getMessages(arg),
    );
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
