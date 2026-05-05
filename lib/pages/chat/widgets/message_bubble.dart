import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/wechat_colors.dart';
import '../../../models/message.dart';
import '../../../models/regex_script.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../models/contact.dart';
import '../../../providers/regex_script_provider.dart';
import '../../../services/regex/regex_service.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final Contact contact;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.contact,
    this.showAvatar = true,
  });

  bool get _isUser => message.role == MessageRole.user;
  bool get _isSystem => message.role == MessageRole.system;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isSystem || message.type == MessageType.system) {
      return _SystemMessage(content: message.content);
    }
    if (message.type == MessageType.transfer) {
      return _TransferBubble(message: message, isUser: _isUser);
    }
    if (message.type == MessageType.delivery) {
      return _DeliveryBubble(message: message, isUser: _isUser);
    }
    if (message.type == MessageType.image) {
      return _ImageBubble(message: message, isUser: _isUser);
    }

    final scripts = ref.watch(enabledRegexScriptsProvider);
    final displayContent = _applyRegex(message, scripts);

    return _TextBubble(
      message: message,
      contact: contact,
      showAvatar: showAvatar,
      displayContent: displayContent,
    );
  }

  String _applyRegex(Message msg, List<RegexScript> scripts) {
    if (scripts.isEmpty) return msg.content;
    const service = RegexService();
    final placement = msg.role == MessageRole.user
        ? RegexPlacement.userInput
        : RegexPlacement.aiOutput;
    return service.applyScripts(msg.content, scripts, placement);
  }
}

class _TextBubble extends StatelessWidget {
  final Message message;
  final Contact contact;
  final bool showAvatar;
  final String displayContent;

  const _TextBubble({
    required this.message,
    required this.contact,
    required this.showAvatar,
    required this.displayContent,
  });

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final reasoningContent = message.metadata?['reasoning_content'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser && showAvatar) ...[
            AvatarWidget.fromContact(contact, size: 40),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (reasoningContent != null && reasoningContent.isNotEmpty)
                  _ThinkingSection(content: reasoningContent),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isUser
                        ? WeChatColors.bubbleSent
                        : WeChatColors.bubbleReceived,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(_isUser ? 12 : 2),
                      topRight: Radius.circular(_isUser ? 2 : 12),
                      bottomLeft: const Radius.circular(12),
                      bottomRight: const Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  child: SelectableText(
                    displayContent,
                    style: const TextStyle(
                      fontSize: 16,
                      color: WeChatColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isUser && showAvatar) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 20,
              backgroundColor: WeChatColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThinkingSection extends StatefulWidget {
  final String content;
  const _ThinkingSection({required this.content});

  @override
  State<_ThinkingSection> createState() => _ThinkingSectionState();
}

class _ThinkingSectionState extends State<_ThinkingSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.psychology,
                    size: 14,
                    color: WeChatColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '思考过程',
                    style: TextStyle(
                      fontSize: 11,
                      color: WeChatColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: WeChatColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                widget.content,
                style: const TextStyle(
                  fontSize: 12,
                  color: WeChatColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String content;
  const _SystemMessage({required this.content});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E5E5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: WeChatColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _TransferBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final amount = message.metadata?['amount'] ?? '';
    final remark = message.metadata?['remark'] ?? '转账';
    final displayContent = amount.isNotEmpty ? '¥$amount' : message.content;
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF89C38),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayContent,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (remark.isNotEmpty)
                            Text(
                              remark,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xAAFFFFFF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5E3C6),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  '微信转账',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9B7B4F)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _ImageBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final path = message.metadata?['path'] ?? message.content;
    final file = File(path);
    final exists = file.existsSync();

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: exists
              ? Image.file(
                  file,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 200,
                    height: 200,
                    color: WeChatColors.textHint.withAlpha(50),
                    child: const Icon(
                      Icons.broken_image,
                      color: WeChatColors.textHint,
                      size: 48,
                    ),
                  ),
                )
              : Container(
                  width: 200,
                  height: 200,
                  color: WeChatColors.textHint.withAlpha(50),
                  child: const Icon(
                    Icons.image,
                    color: WeChatColors.textHint,
                    size: 48,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DeliveryBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _DeliveryBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final shop = message.metadata?['shop'] ?? '外卖店铺';
    final items = message.metadata?['items'] ?? message.content;
    final price = message.metadata?['price'] ?? '';
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: WeChatColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF00B578),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fastfood, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shop,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items, style: const TextStyle(fontSize: 13)),
                    if (price.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '¥$price',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      '美团外卖',
                      style: TextStyle(
                        fontSize: 11,
                        color: WeChatColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
