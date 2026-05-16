import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact.dart';
import 'api_config_provider.dart';

// ─── 联系人列表 Provider ──────────────────────────────────────────────────────

class ContactsNotifier extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() async {
    return ref.read(chatServiceProvider).getContacts();
  }

  Future<void> add(Contact contact) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final service = ref.read(chatServiceProvider);
      final created = await service.createContact(contact);
      return [created, ...?previous.value];
    });
  }

  Future<Contact> addAndReturn(Contact contact) async {
    final service = ref.read(chatServiceProvider);
    try {
      final created = await service.createContact(contact);
      state = AsyncData([created, ...?state.value]);
      return created;
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateContact(Contact contact) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final service = ref.read(chatServiceProvider);
      await service.updateContact(contact);
      return previous.value
              ?.map((c) => c.id == contact.id ? contact : c)
              .toList() ??
          [];
    });
  }

  Future<void> remove(String id) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final service = ref.read(chatServiceProvider);
      await service.deleteContact(id);
      return previous.value?.where((c) => c.id != id).toList() ?? [];
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(chatServiceProvider).getContacts(),
    );
  }

  /// 更新单个联系人（用于未读计数、最后消息等）
  void updateLocal(Contact contact) {
    final list = state.value ?? [];
    final idx = list.indexWhere((c) => c.id == contact.id);
    if (idx >= 0) {
      final newList = List<Contact>.from(list);
      newList[idx] = contact;
      // 按置顶 + 最后消息时间排序
      newList.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(0);
        final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
      state = AsyncData(newList);
    }
  }

  Future<void> clearUnread(String contactId) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      await ref.read(chatServiceProvider).clearUnread(contactId);
      final list = previous.value ?? [];
      final idx = list.indexWhere((c) => c.id == contactId);
      if (idx < 0) return list;
      final newList = List<Contact>.from(list);
      newList[idx] = newList[idx].copyWith(unreadCount: 0);
      return newList;
    });
  }
}

final contactsProvider = AsyncNotifierProvider<ContactsNotifier, List<Contact>>(
  ContactsNotifier.new,
);

// ─── 搜索联系人 Provider ──────────────────────────────────────────────────────

final contactSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredContactsProvider = Provider<AsyncValue<List<Contact>>>((ref) {
  final contacts = ref.watch(contactsProvider);
  final query = ref.watch(contactSearchQueryProvider);

  if (query.isEmpty) return contacts;

  return contacts.whenData(
    (list) => list
        .where(
          (c) =>
              c.name.toLowerCase().contains(query.toLowerCase()) ||
              c.description.toLowerCase().contains(query.toLowerCase()) ||
              c.tags.any((t) => t.toLowerCase().contains(query.toLowerCase())),
        )
        .toList(),
  );
});
