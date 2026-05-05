import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/memory_card.dart';
import '../../models/memory_entry.dart';
import '../../models/memory_state.dart';
import '../../models/contact.dart';
import '../../providers/memory_provider.dart';
import '../../providers/api_config_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/wechat_colors.dart';

class MemoryPage extends ConsumerStatefulWidget {
  final String contactId;
  final Contact? contact;

  const MemoryPage({super.key, required this.contactId, this.contact});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage>
    with SingleTickerProviderStateMixin {
  bool _isExtracting = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoryProvider(widget.contactId));
    final statesAsync = ref.watch(memoryStateProvider(widget.contactId));
    final cardsAsync = ref.watch(memoryCardProvider(widget.contactId));

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: Text('${widget.contact?.name ?? ""}的记忆'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: WeChatColors.primary,
          unselectedLabelColor: WeChatColors.textSecondary,
          tabs: const [
            Tab(text: '记忆条目'),
            Tab(text: '状态板'),
            Tab(text: '记忆卡片'),
          ],
        ),
        actions: [
          if (_isExtracting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '立即提取记忆',
              onPressed: () => _extractNow(context),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearMemories(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('清空记忆', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLegacyTab(memoriesAsync),
          _buildStatesTab(statesAsync),
          _buildCardsTab(cardsAsync),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: WeChatColors.primary,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Legacy memory entries tab ─────────────────────────────────────

  Widget _buildLegacyTab(AsyncValue<List<MemoryEntry>> async) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (entries) {
        if (entries.isEmpty) return _emptyView('暂无记忆', '聊天时将自动提取记忆');
        final categories = <String, List<MemoryEntry>>{};
        for (final entry in entries) {
          categories.putIfAbsent(entry.category, () => []).add(entry);
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final cat in categories.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  cat.key,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: WeChatColors.primary,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < cat.value.length; i++) ...[
                      if (i > 0) const Divider(height: 0, indent: 16),
                      ListTile(
                        onTap: () => _editEntry(context, cat.value[i]),
                        title: Text(
                          cat.value[i].key,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          cat.value[i].value,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: WeChatColors.textHint,
                          ),
                          onPressed: () {
                            ref
                                .read(memoryProvider(widget.contactId).notifier)
                                .deleteEntry(cat.value[i].id);
                          },
                        ),
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ── State board tab ────────────────────────────────────────────────

  Widget _buildStatesTab(AsyncValue<List<MemoryState>> async) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (states) {
        final active = states.where((s) => s.status == 'active').toList();
        if (active.isEmpty) return _emptyView('暂无状态', '聊天后将自动更新状态板');
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < active.length; i++) ...[
                    if (i > 0) const Divider(height: 0, indent: 16),
                    ListTile(
                      title: Text(
                        active[i].slotName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        active[i].slotValue,
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: active[i].confidence >= 0.7
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            active[i].slotType,
                            style: const TextStyle(
                              fontSize: 11,
                              color: WeChatColors.textHint,
                            ),
                          ),
                        ],
                      ),
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Memory cards tab ───────────────────────────────────────────────

  Widget _buildCardsTab(AsyncValue<List<MemoryCard>> async) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (cards) {
        if (cards.isEmpty) return _emptyView('暂无记忆卡片', '聊天时将自动提取长期记忆');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _editCard(context, card),
                title: Text(card.content, style: const TextStyle(fontSize: 14)),
                subtitle: Row(
                  children: [
                    _scoreBadge('重要性', card.importance, Icons.star),
                    const SizedBox(width: 8),
                    _scoreBadge('置信度', card.confidence, Icons.verified),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _scopeColor(card.scope).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        card.scope,
                        style: TextStyle(
                          fontSize: 10,
                          color: _scopeColor(card.scope),
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  card.cardType,
                  style: const TextStyle(
                    fontSize: 11,
                    color: WeChatColors.textHint,
                  ),
                ),
                dense: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _scoreBadge(String label, double value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: value >= 0.7
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: value >= 0.7 ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 2),
          Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(
              fontSize: 10,
              color: value >= 0.7 ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Color _scopeColor(String scope) {
    switch (scope) {
      case 'global':
        return Colors.blue;
      case 'shared':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _emptyView(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.psychology_outlined,
            size: 64,
            color: WeChatColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: WeChatColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: WeChatColors.textHint),
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────

  Future<void> _extractNow(BuildContext context) async {
    final configs = ref.read(apiConfigProvider).value ?? [];
    if (configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先配置 API'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final settings = ref.read(settingsProvider).value;
    final selectedConfig =
        (settings?.memoryUseMainApi == false && configs.length >= 2)
        ? configs[1]
        : configs.first;

    setState(() => _isExtracting = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      await ref
          .read(memoryProvider(widget.contactId).notifier)
          .extractMemories(selectedConfig);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('记忆提取完成'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(
          SnackBar(
            content: Text('提取失败: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _clearMemories(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空记忆'),
        content: const Text('确定清空该联系人的所有记忆？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(memoryProvider(widget.contactId).notifier).clearAll();
    }
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final tabIdx = _tabController.index;
    if (tabIdx == 0) {
      final result = await showDialog<_EntryEditResult>(
        context: context,
        builder: (ctx) => _EntryEditDialog(),
      );
      if (result != null) {
        await ref.read(memoryProvider(widget.contactId).notifier).addEntry(
              result.category,
              result.key,
              result.value,
            );
      }
    } else if (tabIdx == 2) {
      final result = await showDialog<MemoryCard>(
        context: context,
        builder: (ctx) => _CardEditDialog(),
      );
      if (result != null) {
        await ref.read(memoryCardProvider(widget.contactId).notifier).addCard(
              result,
            );
      }
    }
  }

  Future<void> _editEntry(BuildContext context, MemoryEntry entry) async {
    final result = await showDialog<_EntryEditResult>(
      context: context,
      builder: (ctx) => _EntryEditDialog(
        existingCategory: entry.category,
        existingKey: entry.key,
        existingValue: entry.value,
      ),
    );
    if (result != null) {
      await ref.read(memoryProvider(widget.contactId).notifier).updateEntry(
            entry.copyWith(
              category: result.category,
              key: result.key,
              value: result.value,
            ),
          );
    }
  }

  Future<void> _editCard(BuildContext context, MemoryCard card) async {
    final result = await showDialog<MemoryCard>(
      context: context,
      builder: (ctx) => _CardEditDialog(existing: card),
    );
    if (result != null) {
      await ref.read(memoryCardProvider(widget.contactId).notifier).updateCard(
            result,
          );
    }
  }
}

class _EntryEditResult {
  final String category;
  final String key;
  final String value;
  const _EntryEditResult({
    required this.category,
    required this.key,
    required this.value,
  });
}

class _EntryEditDialog extends StatefulWidget {
  final String? existingCategory;
  final String? existingKey;
  final String? existingValue;
  const _EntryEditDialog({
    this.existingCategory,
    this.existingKey,
    this.existingValue,
  });

  @override
  State<_EntryEditDialog> createState() => _EntryEditDialogState();
}

class _EntryEditDialogState extends State<_EntryEditDialog> {
  late final _catCtrl = TextEditingController(
    text: widget.existingCategory ?? '',
  );
  late final _keyCtrl = TextEditingController(
    text: widget.existingKey ?? '',
  );
  late final _valueCtrl = TextEditingController(
    text: widget.existingValue ?? '',
  );
  bool get isEditing => widget.existingKey != null;

  @override
  void dispose() {
    _catCtrl.dispose();
    _keyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? '编辑记忆条目' : '新增记忆条目'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _catCtrl,
            decoration: const InputDecoration(labelText: '分类', hintText: '例如: 偏好, 事实'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(labelText: '键', hintText: '例如: 喜欢的食物'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valueCtrl,
            decoration: const InputDecoration(labelText: '值', hintText: '例如: 寿司'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_keyCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _EntryEditResult(
                category: _catCtrl.text.trim(),
                key: _keyCtrl.text.trim(),
                value: _valueCtrl.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _CardEditDialog extends StatefulWidget {
  final MemoryCard? existing;
  const _CardEditDialog({this.existing});

  @override
  State<_CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<_CardEditDialog> {
  late final _contentCtrl = TextEditingController(
    text: widget.existing?.content ?? '',
  );
  late String _cardType = widget.existing?.cardType ?? 'fact';
  late double _importance = widget.existing?.importance ?? 0.8;
  late double _confidence = widget.existing?.confidence ?? 0.9;
  late String _scope = widget.existing?.scope ?? 'local';

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增记忆卡片' : '编辑记忆卡片'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _contentCtrl,
            decoration: const InputDecoration(labelText: '内容', hintText: '记忆内容'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cardType,
            decoration: const InputDecoration(labelText: '类型'),
            items: const [
              DropdownMenuItem(value: 'fact', child: Text('事实')),
              DropdownMenuItem(value: 'event', child: Text('事件')),
              DropdownMenuItem(value: 'preference', child: Text('偏好')),
              DropdownMenuItem(value: 'boundary', child: Text('边界')),
              DropdownMenuItem(value: 'relationship', child: Text('关系')),
            ],
            onChanged: (v) => setState(() => _cardType = v ?? 'fact'),
          ),
          const SizedBox(height: 12),
          Text('重要性: ${(_importance * 100).toInt()}%'),
          Slider(
            value: _importance,
            min: 0, max: 1, divisions: 10,
            onChanged: (v) => setState(() => _importance = v),
          ),
          Text('置信度: ${(_confidence * 100).toInt()}%'),
          Slider(
            value: _confidence,
            min: 0, max: 1, divisions: 10,
            onChanged: (v) => setState(() => _confidence = v),
          ),
          DropdownButtonFormField<String>(
            initialValue: _scope,
            decoration: const InputDecoration(labelText: '范围'),
            items: const [
              DropdownMenuItem(value: 'local', child: Text('本地')),
              DropdownMenuItem(value: 'shared', child: Text('共享')),
              DropdownMenuItem(value: 'global', child: Text('全局')),
            ],
            onChanged: (v) => setState(() => _scope = v ?? 'local'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_contentCtrl.text.trim().isEmpty) return;
            final card = (widget.existing ?? MemoryCard(
              id: '',
              contactId: '',
              content: '',
              cardType: 'fact',
              importance: 0.5,
              confidence: 0.5,
              scope: 'local',
              status: 'active',
              createdAt: DateTime.now(),
            )).copyWith(
              content: _contentCtrl.text.trim(),
              cardType: _cardType,
              importance: _importance,
              confidence: _confidence,
              scope: _scope,
              reviewedAt: DateTime.now(),
            );
            Navigator.pop(context, card);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
