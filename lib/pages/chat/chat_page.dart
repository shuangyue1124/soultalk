import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/api_config_provider.dart';
import '../../theme/wechat_colors.dart';
import '../../models/voice_config.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/chat/typing_simulator.dart';
import '../../services/tts/tts_service.dart';
import 'widgets/message_bubble.dart';
import 'widgets/input_bar.dart';
import 'widgets/typing_indicator.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String contactId;
  final Contact? contact;

  const ChatPage({super.key, required this.contactId, this.contact});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isTyping = false;
  bool _isRecording = false;
  bool _hasReceivedFirstChunk = false;
  bool _ttsEnabled = false;
  String? _lastUserText;
  String? _lastAiMsgId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge &&
          _scrollController.position.pixels <= 0) {
        _loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      ref.read(contactsProvider.notifier).clearUnread(widget.contactId);
    });
    _loadTtsSetting();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  Future<void> _sendMessage(Contact contact, String text) async {
    if (_isSending) return;
    _lastUserText = text;
    setState(() {
      _isSending = true;
      _isTyping = true;
      _hasReceivedFirstChunk = false;
    });

    final messagesNotifier = ref.read(
      messagesProvider(widget.contactId).notifier,
    );

    await TypingSimulator.simulateDelay(text);
    if (!mounted) return;

    // 保持 _isTyping = true，在 API 返回第一个 chunk 时再隐藏

    ref
        .read(chatServiceProvider)
        .sendMessage(
          contact: contact,
          userText: text,
          onMessagesCreated: (userMsg, aiMsg) {
            _lastAiMsgId = aiMsg.id;
            messagesNotifier.addMessage(userMsg);
            messagesNotifier.addMessage(aiMsg);
            _scrollToBottom(animated: true);
          },
          onAiChunk: (content, isDone) {
            if (!_hasReceivedFirstChunk && mounted) {
              setState(() => _hasReceivedFirstChunk = true);
              _delayedHideTyping();
            }

            final msgs =
                ref.read(messagesProvider(widget.contactId)).value ?? [];
            if (msgs.isNotEmpty) {
              final lastMsg = msgs.last;
              if (lastMsg.role == MessageRole.assistant) {
                messagesNotifier.updateLastMessage(
                  lastMsg.id,
                  content,
                  isStreaming: !isDone,
                );
                _scrollToBottom(animated: false);
              }
            }
            if (isDone) {
              if (mounted) setState(() => _isSending = false);
              ref.read(contactsProvider.notifier).refresh();
              if (_ttsEnabled) {
                _speakAiResponse(content);
              }
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isSending = false;
                _isTyping = false;
                _hasReceivedFirstChunk = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('发送失败: $error'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: '重试',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      // Remove failed AI placeholder
                      if (_lastAiMsgId != null) {
                        messagesNotifier.removeMessage(_lastAiMsgId!);
                      }
                      if (_lastUserText != null) {
                        _sendMessage(contact, _lastUserText!);
                      }
                    },
                  ),
                ),
              );
            }
          },
        );
  }

  void _delayedHideTyping() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isTyping = false);
    });
  }

  Future<void> _loadTtsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ttsEnabled = prefs.getBool('tts_enabled_${widget.contactId}') ?? false;
      });
    }
  }

  Future<void> _toggleTts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_enabled_${widget.contactId}', value);
    setState(() => _ttsEnabled = value);
  }

  Future<void> _speakAiResponse(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ttsConfig = await TtsConfig.load(prefs);
      if (ttsConfig.apiKey.isEmpty) return;

      // Strip memory markers so internal instructions are never spoken
      final cleanText = TtsService.stripMemoryMarkers(text);
      if (cleanText.isEmpty) return;

      final service = TtsService();
      final filePath = await service.synthesize(ttsConfig, cleanText);
      if (filePath == null || !mounted) return;

      final player = AudioPlayer();
      await player.setFilePath(filePath);
      await player.play();
      // Auto-dispose after playback completes
      player.processingStateStream
          .where((s) => s == ProcessingState.completed)
          .first
          .then((_) {
            player.dispose();
            try {
              File(filePath).delete();
            } catch (_) {}
          });
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    final notifier = ref.read(messagesProvider(widget.contactId).notifier);
    await notifier.loadMore();
  }

  Future<void> _onMicTap() async {
    final prefs = await SharedPreferences.getInstance();
    final sttConfig = await SttConfig.load(prefs);
    if (sttConfig.apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('请先在通用设置中配置语音识别（STT）API'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '去设置',
              onPressed: () => context.push('/settings/general'),
            ),
          ),
        );
      }
      return;
    }
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始录音...（再次点击停止）'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('录音已停止，正在识别...'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMessageActions(BuildContext context, Message message) {
    final isUser = message.role == MessageRole.user;
    final isAiError =
        message.role == MessageRole.assistant &&
        !message.isStreaming &&
        message.content.isEmpty;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAiError)
              ListTile(
                leading: const Icon(Icons.refresh, color: WeChatColors.primary),
                title: const Text('重新生成'),
                subtitle: const Text(
                  '使用当前配置重新发送上一条消息',
                  style: TextStyle(
                    fontSize: 12,
                    color: WeChatColors.textSecondary,
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ref
                      .read(messagesProvider(widget.contactId).notifier)
                      .removeMessage(message.id);
                  final contact = ref
                      .read(contactsProvider)
                      .value
                      ?.where((c) => c.id == widget.contactId)
                      .firstOrNull;
                  if (contact != null && _lastUserText != null) {
                    _sendMessage(contact, _lastUserText!);
                  }
                },
              ),
            if (isUser)
              ListTile(
                leading: const Icon(Icons.undo, color: WeChatColors.primary),
                title: const Text('撤回消息'),
                subtitle: const Text(
                  'AI 会知道此消息被撤回',
                  style: TextStyle(
                    fontSize: 12,
                    color: WeChatColors.textSecondary,
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  ref
                      .read(messagesProvider(widget.contactId).notifier)
                      .retractMessage(message.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除消息'),
              subtitle: const Text(
                'AI 不会知道此消息被删除',
                style: TextStyle(
                  fontSize: 12,
                  color: WeChatColors.textSecondary,
                ),
              ),
              onTap: () {
                ctx.pop();
                ref
                    .read(messagesProvider(widget.contactId).notifier)
                    .removeMessage(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImageMessage(Contact contact, String imagePath) async {
    final messagesNotifier = ref.read(
      messagesProvider(widget.contactId).notifier,
    );
    final userMsg = Message(
      id: '',
      contactId: widget.contactId,
      role: MessageRole.user,
      content: imagePath,
      type: MessageType.image,
      metadata: {'path': imagePath},
      createdAt: DateTime.now(),
    );
    final service = ref.read(chatServiceProvider);
    final saved = await service.saveMessage(userMsg);
    messagesNotifier.addMessage(saved);
    _scrollToBottom(animated: true);
    ref.read(contactsProvider.notifier).refresh();
  }

  Future<void> _sendSpecialMessage(
    Contact contact,
    String type,
    Map<String, dynamic> metadata,
  ) async {
    final messagesNotifier = ref.read(
      messagesProvider(widget.contactId).notifier,
    );
    final msgType = type == 'transfer'
        ? MessageType.transfer
        : MessageType.delivery;
    String content;
    if (type == 'transfer') {
      content = '¥${metadata['amount']}';
    } else {
      content = '${metadata['shop']} - ${metadata['items']}';
    }

    final userMsg = Message(
      id: '',
      contactId: widget.contactId,
      role: MessageRole.user,
      content: content,
      type: msgType,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    final service = ref.read(chatServiceProvider);
    final saved = await service.saveMessage(userMsg);
    messagesNotifier.addMessage(saved);
    _scrollToBottom(animated: true);
    ref.read(contactsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref
        .watch(contactsProvider)
        .whenData(
          (contacts) =>
              contacts.where((c) => c.id == widget.contactId).firstOrNull,
        );
    final contact = contactAsync.value ?? widget.contact;

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('聊天')),
        body: const Center(child: Text('联系人不存在')),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(widget.contactId));

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget.fromContact(contact, size: 32),
                const SizedBox(width: 8),
                Text(contact.name),
              ],
            ),
            if (_isTyping)
              const Text(
                '对方正在输入...',
                style: TextStyle(
                  fontSize: 11,
                  color: WeChatColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showChatMenu(context, contact),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (messages) {
                if (messages.isEmpty && !_isTyping) {
                  return _buildEmptyChat(contact);
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      final msg = messages[index];
                      return GestureDetector(
                        onLongPress: () => _showMessageActions(context, msg),
                        child: MessageBubble(message: msg, contact: contact),
                      );
                    }
                    return const TypingIndicator();
                  },
                );
              },
            ),
          ),
          // 输入栏
          InputBar(
            onSend: (text) => _sendMessage(contact, text),
            onSendSpecial: (type, metadata) =>
                _sendSpecialMessage(contact, type, metadata),
            onSendImage: (path) => _sendImageMessage(contact, path),
            onMicTap: _onMicTap,
            enabled: !_isSending,
            isRecording: _isRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(Contact contact) {
    final hasFirstMes = contact.characterCardJson != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarWidget.fromContact(contact, size: 64),
          const SizedBox(height: 12),
          Text(
            contact.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (contact.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                contact.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: WeChatColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            hasFirstMes ? '开始对话' : '发送一条消息开始聊天',
            style: const TextStyle(color: WeChatColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showChatMenu(BuildContext context, Contact contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('联系人资料'),
              onTap: () {
                ctx.pop();
                context.push('/contact/detail/${contact.id}', extra: contact);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.push_pin_outlined),
              title: const Text('置顶会话'),
              value: contact.pinned,
              activeThumbColor: WeChatColors.primary,
              onChanged: (v) {
                ctx.pop();
                ref
                    .read(contactsProvider.notifier)
                    .updateContact(contact.copyWith(pinned: v));
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_mode),
              title: const Text('允许主动联系'),
              value: contact.proactiveEnabled,
              activeThumbColor: WeChatColors.primary,
              onChanged: (v) {
                ctx.pop();
                ref
                    .read(contactsProvider.notifier)
                    .updateContact(contact.copyWith(proactiveEnabled: v));
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('语音回复'),
              subtitle: const Text('使用 TTS 朗读 AI 回复'),
              value: _ttsEnabled,
              activeThumbColor: WeChatColors.primary,
              onChanged: (v) {
                ctx.pop();
                _toggleTts(v);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('记忆表格'),
              onTap: () {
                ctx.pop();
                context.push('/memory/${contact.id}', extra: contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.api_outlined),
              title: const Text('API 配置'),
              onTap: () {
                ctx.pop();
                context.push('/settings/api');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑联系人'),
              onTap: () {
                ctx.pop();
                _editContact(context, contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('清空聊天记录'),
              onTap: () async {
                ctx.pop();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('清空记录'),
                    content: const Text('确定清空所有聊天记录？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(true),
                        child: const Text(
                          '清空',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(messagesProvider(widget.contactId).notifier)
                      .clearMessages();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除联系人', style: TextStyle(color: Colors.red)),
              onTap: () {
                ctx.pop();
                _deleteContact(context, contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact(BuildContext context, Contact contact) async {
    final configs = ref.read(apiConfigProvider).value ?? [];
    final result = await showDialog<Contact>(
      context: context,
      builder: (ctx) =>
          _ChatEditContactDialog(contact: contact, configs: configs),
    );
    if (result != null) {
      await ref.read(contactsProvider.notifier).updateContact(result);
    }
  }

  Future<void> _deleteContact(BuildContext context, Contact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除 "${contact.name}"？相关聊天记录将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(contactsProvider.notifier).remove(contact.id);
      if (mounted) GoRouter.of(this.context).pop();
    }
  }
}

class _ChatEditContactDialog extends StatefulWidget {
  final Contact contact;
  final List<ApiConfig> configs;
  const _ChatEditContactDialog({required this.contact, required this.configs});

  @override
  State<_ChatEditContactDialog> createState() => _ChatEditContactDialogState();
}

class _ChatEditContactDialogState extends State<_ChatEditContactDialog> {
  late final _nameCtrl = TextEditingController(text: widget.contact.name);
  late final _descCtrl = TextEditingController(
    text: widget.contact.description,
  );
  late final _promptCtrl = TextEditingController(
    text: widget.contact.systemPrompt,
  );
  late String? _selectedConfigId = widget.contact.apiConfigId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑联系人'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: '简介'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptCtrl,
              decoration: const InputDecoration(labelText: 'System Prompt'),
              maxLines: 4,
            ),
            if (widget.configs.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedConfigId,
                decoration: const InputDecoration(labelText: '绑定 API'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('不绑定')),
                  ...widget.configs.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedConfigId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              widget.contact.copyWith(
                name: _nameCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                systemPrompt: _promptCtrl.text.trim(),
                apiConfigId: _selectedConfigId,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
