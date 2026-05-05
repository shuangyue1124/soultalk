import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/moment.dart';
import '../../models/contact.dart';
import '../../providers/moments_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../theme/wechat_colors.dart';
import '../../widgets/avatar_widget.dart';

class MomentsPage extends ConsumerStatefulWidget {
  const MomentsPage({super.key});

  @override
  ConsumerState<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends ConsumerState<MomentsPage> {
  @override
  Widget build(BuildContext context) {
    final momentsAsync = ref.watch(momentsProvider);
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: WeChatColors.appBarBackground,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: '生成新动态',
                onPressed: () => _generateMoments(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                '朋友圈',
                style: TextStyle(color: WeChatColors.textPrimary),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: WeChatColors.primary,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'SoulTalk 用户',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          momentsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('加载失败: $e'))),
            data: (moments) {
              if (moments.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: WeChatColors.textHint,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '朋友圈暂无动态',
                          style: TextStyle(color: WeChatColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generateMoments,
                          child: const Text('让 AI 发一些动态'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final contacts = contactsAsync.value ?? <Contact>[];
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final moment = moments[index];
                  final contact = contacts
                      .where((c) => c.id == moment.contactId)
                      .firstOrNull;
                  return _MomentCard(
                    moment: moment,
                    contact: contact,
                    onLike: () => ref
                        .read(momentsProvider.notifier)
                        .toggleLike(moment.id),
                    onComment: (text) => _onComment(moment, contact, text),
                  );
                }, childCount: moments.length),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generateMoments() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在生成朋友圈动态...'),
        duration: Duration(seconds: 3),
      ),
    );
    await ref.read(momentsProvider.notifier).generateMoments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新动态已生成'), duration: Duration(seconds: 3)),
      );
    }
  }

  Future<void> _onComment(Moment moment, Contact? contact, String text) async {
    final userComment = MomentComment(
      authorId: 'user',
      authorName: 'SoulTalk 用户',
      content: text,
      createdAt: DateTime.now(),
    );
    await ref.read(momentsProvider.notifier).addComment(moment.id, userComment);

    if (contact != null) {
      final reply = await ref
          .read(momentsServiceProvider)
          .generateAiReply(moment.id, text, contact);
      if (reply != null) {
        final aiComment = MomentComment(
          authorId: contact.id,
          authorName: contact.name,
          content: reply,
          replyToName: 'SoulTalk 用户',
          createdAt: DateTime.now(),
        );
        await ref
            .read(momentsProvider.notifier)
            .addComment(moment.id, aiComment);
      }
    }
  }
}

class _MomentCard extends StatelessWidget {
  final Moment moment;
  final Contact? contact;
  final VoidCallback onLike;
  final void Function(String text) onComment;

  const _MomentCard({
    required this.moment,
    this.contact,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = moment.likes.contains('user');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact != null)
                AvatarWidget.fromContact(contact!, size: 44)
              else
                const CircleAvatar(radius: 22, child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact?.name ?? '未知',
                      style: const TextStyle(
                        color: Color(0xFF576B95),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      moment.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: WeChatColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 时间 + 操作
          Row(
            children: [
              const SizedBox(width: 54),
              Text(
                _formatTime(moment.createdAt ?? DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  color: WeChatColors.textHint,
                ),
              ),
              const Spacer(),
              _ActionMenu(
                isLiked: isLiked,
                onLike: onLike,
                onComment: () => _showCommentInput(context),
              ),
            ],
          ),
          // 点赞 & 评论区
          if (moment.likes.isNotEmpty || moment.comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 54),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (moment.likes.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 14,
                          color: Color(0xFF576B95),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            moment.likes
                                .map((l) => l == 'user' ? 'SoulTalk 用户' : l)
                                .join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF576B95),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (moment.comments.isNotEmpty) const Divider(height: 12),
                  ],
                  ...moment.comments.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: WeChatColors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: c.authorName,
                              style: const TextStyle(
                                color: Color(0xFF576B95),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (c.replyToName != null) ...[
                              const TextSpan(text: ' 回复 '),
                              TextSpan(
                                text: c.replyToName!,
                                style: const TextStyle(
                                  color: Color(0xFF576B95),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            TextSpan(text: ': ${c.content}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 20),
        ],
      ),
    );
  }

  void _showCommentInput(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 12,
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '评论...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (ctrl.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop();
                  onComment(ctrl.text.trim());
                },
                child: const Text('发送'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}月${dt.day}日';
  }
}

class _ActionMenu extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _ActionMenu({
    required this.isLiked,
    required this.onLike,
    required this.onComment,
  });

  @override
  State<_ActionMenu> createState() => _ActionMenuState();
}

class _ActionMenuState extends State<_ActionMenu> {
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    if (!_showActions) {
      return GestureDetector(
        onTap: () => setState(() => _showActions = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4B5563),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.more_horiz, color: Colors.white, size: 16),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4B5563),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: () {
              widget.onLike();
              setState(() => _showActions = false);
            },
            icon: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
              size: 14,
            ),
            label: Text(
              widget.isLiked ? '取消' : '赞',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(
            height: 20,
            child: VerticalDivider(color: Colors.white38),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => _showActions = false);
              widget.onComment();
            },
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 14,
            ),
            label: const Text(
              '评论',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
