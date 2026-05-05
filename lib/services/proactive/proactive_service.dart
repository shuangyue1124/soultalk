import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../database/contact_dao.dart';
import '../database/message_dao.dart';
import '../database/api_config_dao.dart';
import '../api/llm_service.dart';
import '../moments/moments_service.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../../models/moment.dart';

class ProactiveService {
  static final ProactiveService _instance = ProactiveService._internal();
  factory ProactiveService() => _instance;
  ProactiveService._internal();

  Timer? _timer;
  final _random = Random();
  late final ContactDao _contactDao;
  late final MessageDao _messageDao;
  late final ApiConfigDao _apiConfigDao;
  bool _initialized = false;

  void Function()? onNewMessage;

  static const _kLastSeenKey = 'proactive_last_seen_at';

  void init() {
    if (_initialized) return;
    _initialized = true;
    final db = DatabaseService();
    _contactDao = ContactDao(db);
    _messageDao = MessageDao(db);
    _apiConfigDao = ApiConfigDao(db);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  /// 记录用户最后一次活跃时间（由 App 生命周期监听调用）
  Future<void> recordUserActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSeenKey, DateTime.now().millisecondsSinceEpoch);
  }

  int _checkCount = 0;

  Future<void> _check() async {
    final now = DateTime.now();
    if (now.hour >= 23 || now.hour < 7) return;

    final prefs = await SharedPreferences.getInstance();
    final momentsInterval = prefs.getInt('moments_interval_minutes') ?? 60;
    final checksNeeded = (momentsInterval / 5).round().clamp(1, 288);

    _checkCount++;
    if (_checkCount % checksNeeded == 0) {
      MomentsService().init();
      await MomentsService().generateMomentsForAllContacts();
      await _aiAutoInteractWithMoments();
    }

    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    for (final contact in contacts) {
      if (!contact.proactiveEnabled) continue;
      if (contact.systemPrompt.isEmpty && contact.characterCardJson == null) {
        continue;
      }

      final lastProactive = contact.lastProactiveAt;
      final minHours = 2 + _random.nextInt(7);
      if (lastProactive != null &&
          now.difference(lastProactive).inHours < minHours) {
        continue;
      }

      if (_random.nextDouble() > 0.3) continue;

      await _sendProactiveMessage(contact, configs);
    }
  }

  /// APP 启动时调用：对比用户离开与返回时间，触发自动行为
  Future<void> checkOnAppOpen() async {
    if (!_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // ── 1. 计算离开时长 ──────────────────────────────────────────────
    final lastSeenMs = prefs.getInt(_kLastSeenKey);
    Duration awayDuration = Duration.zero;
    if (lastSeenMs != null) {
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMs);
      awayDuration = now.difference(lastSeen);
    }

    // ── 2. 更新最后活跃时间 ───────────────────────────────────────────
    await prefs.setInt(_kLastSeenKey, now.millisecondsSinceEpoch);

    // ── 3. 离开足够久 → 触发朋友圈生成 ──────────────────────────────
    final momentsInterval = prefs.getInt('moments_interval_minutes') ?? 60;
    if (awayDuration.inMinutes >= momentsInterval) {
      MomentsService().init();
      await MomentsService().generateMomentsForAllContacts();
      await _aiAutoInteractWithMoments();
    }

    // ── 4. 检查自动回复/主动消息 ─────────────────────────────────────
    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    for (final contact in contacts) {
      if (!contact.proactiveEnabled) continue;
      if (contact.systemPrompt.isEmpty && contact.characterCardJson == null) {
        continue;
      }

      final lastMsgTime = contact.lastMessageAt;
      if (lastMsgTime == null) continue;

      final timeDiff = now.difference(lastMsgTime);

      // ── 4a. 自动回复：取 API 计划时间与系统时间对比 ────────────
      final scheduledMsg = await _fetchScheduledMessage(contact, configs);
      if (scheduledMsg != null) {
        // 【已确认】API 返回了计划发送的消息
        final apiTime = scheduledMsg.scheduledAt;
        final diff = apiTime.difference(now).abs();

        if (diff.inHours <= 1) {
          // 差异 ≤ 1 小时 → 以 API 时间为准，在指定时间发送
          await _sendScheduledMessage(contact, configs, scheduledMsg);
        } else {
          // 差异 > 1 小时 → 触发告警
          _alertTimeMismatch(contact, apiTime, now);
        }
        continue;
      }

      // ── 4b. 超过 2 小时未互动 → 概率性主动发消息 ─────────────────
      if (timeDiff.inHours >= 2) {
        final chance = (timeDiff.inHours / 24.0).clamp(0.1, 0.8);
        if (_random.nextDouble() < chance) {
          await _sendProactiveMessage(contact, configs);
        }
      }
    }
  }

  /// 从 API 获取计划消息（用于自动回复验证）
  /// 【推测】此 API 接口需自行实现或对接外部调度服务
  Future<ScheduledMessage?> _fetchScheduledMessage(
    Contact contact,
    List<ApiConfig> configs,
  ) async {
    // 优先使用联系人的绑定 API，否则取第一个配置
    ApiConfig? config;
    if (contact.apiConfigId != null) {
      config = configs.where((c) => c.id == contact.apiConfigId).firstOrNull;
    }
    config ??= configs.first;

    try {
      // 【推测】此处调用 LLM 判断是否需要主动发送消息：
      // 可扩展为从外部调度服务获取计划消息
      final service = LlmService.fromConfig(config);
      final now = DateTime.now();

      final systemPrompt =
          '''${contact.systemPrompt}

你正在检查是否需要主动给对方发一条消息。
当前时间：${now.toString()}
对方上次消息时间：${contact.lastMessageAt?.toString() ?? '未知'}

请判断：
1. 是否需要主动发消息？（是/否）
2. 如果需要，你准备说什么内容？（1-2句话）
3. 你希望的发送时间是什么？（回复格式：YYYY-MM-DD HH:MM）

请按 JSON 格式回复：
{"shouldSend": true/false, "content": "消息内容", "scheduledTime": "2026-05-03 09:00"}''';

      final reply = await service.sendMessage(
        config: config,
        messages: [
          Message(
            id: 'schedule-check',
            contactId: contact.id,
            role: MessageRole.user,
            content: '检查是否需要自动回复',
          ),
        ],
        systemPrompt: systemPrompt,
      );

      if (reply.trim().isEmpty) return null;

      // 【推测】解析 LLM 返回的 JSON
      try {
        final jsonStart = reply.indexOf('{');
        final jsonEnd = reply.lastIndexOf('}');
        if (jsonStart == -1 || jsonEnd == -1) return null;

        final jsonStr = reply.substring(jsonStart, jsonEnd + 1);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        if (data['shouldSend'] == true && data['content'] != null) {
          final scheduledTime =
              DateTime.tryParse(data['scheduledTime']?.toString() ?? '') ?? now;
          return ScheduledMessage(
            content: data['content'].toString(),
            scheduledAt: scheduledTime,
          );
        }
      } catch (_) {
        return null;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendScheduledMessage(
    Contact contact,
    List<ApiConfig> configs,
    ScheduledMessage msg,
  ) async {
    final service = LlmService.fromConfig(
      configs.firstWhere(
        (c) => c.id == contact.apiConfigId,
        orElse: () => configs.first,
      ),
    );

    try {
      final reply = await service.sendMessage(
        config: configs.firstWhere(
          (c) => c.id == contact.apiConfigId,
          orElse: () => configs.first,
        ),
        messages: [
          Message(
            id: 'scheduled',
            contactId: contact.id,
            role: MessageRole.user,
            content: '（系统触发：自动回复）${msg.content}',
          ),
        ],
        systemPrompt:
            '''${contact.systemPrompt}

请将以下消息以你的说话风格发送给对方，要求自然不做作：
${msg.content}

直接输出消息内容，不要加任何前缀。''',
      );

      if (reply.trim().isEmpty) return;

      await _messageDao.insert(
        Message(
          id: '',
          contactId: contact.id,
          role: MessageRole.assistant,
          content: reply.trim(),
          createdAt: msg.scheduledAt, // 使用 API 指定的时间
        ),
      );

      await _contactDao.updateLastMessage(
        contact.id,
        reply.trim(),
        msg.scheduledAt,
      );
      await _contactDao.incrementUnread(contact.id);

      final db = await DatabaseService().database;
      await db.update(
        'contacts',
        {'last_proactive_at': msg.scheduledAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [contact.id],
      );

      onNewMessage?.call();
    } catch (_) {}
  }

  /// 时间差异 > 1 小时的告警
  void _alertTimeMismatch(
    Contact contact,
    DateTime apiTime,
    DateTime systemTime,
  ) {
    // 【已确认】差异超过 1 小时 → 告警记录
    final diff = apiTime.difference(systemTime).abs();
    // ignore: avoid_print
    print(
      '[TimeAlert] contact: ${contact.name}, '
      'apiTime: $apiTime, systemTime: $systemTime, diff: ${diff.inMinutes}m',
    );
  }

  /// AI 自动对朋友圈进行点赞和评论
  Future<void> _aiAutoInteractWithMoments() async {
    final momentsService = MomentsService();
    momentsService.init();
    final moments = await momentsService.getAllMoments(limit: 10);
    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    for (final moment in moments) {
      final momentAuthor = contacts
          .where((c) => c.id == moment.contactId)
          .firstOrNull;
      if (momentAuthor == null) continue;

      // 其他 AI 联系人对这条朋友圈进行互动
      for (final otherContact in contacts) {
        if (otherContact.id == moment.contactId) continue;
        if (!otherContact.proactiveEnabled) continue;
        if (otherContact.systemPrompt.isEmpty &&
            otherContact.characterCardJson == null) {
          continue;
        }

        // 已经互动过就跳过
        if (moment.likes.contains(otherContact.id)) continue;
        final alreadyCommented = moment.comments.any(
          (c) => c.authorId == otherContact.id,
        );
        if (alreadyCommented) continue;

        // 30% 概率点赞
        if (_random.nextDouble() < 0.3) {
          await momentsService.toggleLike(moment.id, otherContact.id);
        }

        // 20% 概率评论
        if (_random.nextDouble() < 0.2) {
          await _aiCommentOnMoment(
            momentsService,
            moment,
            otherContact,
            configs,
          );
        }
      }
    }
  }

  Future<void> _aiCommentOnMoment(
    MomentsService momentsService,
    Moment moment,
    Contact commenter,
    List<ApiConfig> configs,
  ) async {
    ApiConfig config = configs.first;
    if (commenter.apiConfigId != null) {
      config =
          configs.where((c) => c.id == commenter.apiConfigId).firstOrNull ??
          config;
    }

    final systemPrompt =
        '''${commenter.systemPrompt}

你看到朋友圈一条动态: "${moment.content}"
请你以自己的身份写一条评论。
要求：
- 简短自然，1-2句话
- 符合你的角色性格
- 直接输出评论内容''';

    final service = LlmService.fromConfig(config);
    try {
      final reply = await service.sendMessage(
        config: config,
        messages: [
          Message(
            id: 'comment',
            contactId: commenter.id,
            role: MessageRole.user,
            content: '评论这条朋友圈',
          ),
        ],
        systemPrompt: systemPrompt,
      );

      if (reply.trim().isNotEmpty) {
        await momentsService.addComment(
          moment.id,
          MomentComment(
            authorId: commenter.id,
            authorName: commenter.name,
            content: reply.trim(),
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _sendProactiveMessage(
    Contact contact,
    List<ApiConfig> configs,
  ) async {
    ApiConfig? config;
    if (contact.apiConfigId != null) {
      config = configs.where((c) => c.id == contact.apiConfigId).firstOrNull;
    }
    config ??= configs.first;

    final proactiveTypes = [
      '发一条日常问候消息',
      '分享一件你最近经历的有趣的事',
      '随便聊聊最近的心情',
      '分享一个你的想法或感悟',
      '问候对方最近怎么样',
      '分享你正在做的事情',
    ];
    final selectedType = proactiveTypes[_random.nextInt(proactiveTypes.length)];

    final hour = DateTime.now().hour;
    String timeContext;
    if (hour < 9) {
      timeContext = '现在是早上';
    } else if (hour < 12) {
      timeContext = '现在是上午';
    } else if (hour < 14) {
      timeContext = '现在是中午';
    } else if (hour < 18) {
      timeContext = '现在是下午';
    } else {
      timeContext = '现在是晚上';
    }

    final systemPrompt =
        '''${contact.systemPrompt}

你现在要主动给对方发一条消息。$timeContext。
请你$selectedType。
要求：
- 像真人一样自然，不要太正式
- 简短，1-3句话
- 符合你的角色性格
- 不要用"亲爱的"等过于亲密的称呼（除非角色设定如此）
- 直接输出消息内容，不要加任何前缀''';

    final service = LlmService.fromConfig(config);
    try {
      final dummyMsg = Message(
        id: 'ctx',
        contactId: contact.id,
        role: MessageRole.user,
        content: '（用户暂时不在线）',
      );

      final reply = await service.sendMessage(
        config: config,
        messages: [dummyMsg],
        systemPrompt: systemPrompt,
      );

      if (reply.trim().isEmpty) return;

      await _messageDao.insert(
        Message(
          id: '',
          contactId: contact.id,
          role: MessageRole.assistant,
          content: reply.trim(),
          createdAt: DateTime.now(),
        ),
      );

      await _contactDao.updateLastMessage(
        contact.id,
        reply.trim(),
        DateTime.now(),
      );
      await _contactDao.incrementUnread(contact.id);

      final db = await DatabaseService().database;
      await db.update(
        'contacts',
        {'last_proactive_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [contact.id],
      );

      onNewMessage?.call();
    } catch (_) {}
  }
}

/// 计划消息模型，用于自动回复验证
class ScheduledMessage {
  final String content;
  final DateTime scheduledAt;

  const ScheduledMessage({required this.content, required this.scheduledAt});
}
