import 'dart:math';
import '../database/database_service.dart';
import '../database/contact_dao.dart';
import '../database/moment_dao.dart';
import '../database/api_config_dao.dart';
import '../api/llm_service.dart';
import '../extensions/extension_event_bus.dart';
import '../../models/contact.dart';
import '../../models/moment.dart';
import '../../models/message.dart';

class MomentsService {
  static final MomentsService _instance = MomentsService._internal();
  factory MomentsService() => _instance;
  MomentsService._internal();

  late final ContactDao _contactDao;
  late final MomentDao _momentDao;
  late final ApiConfigDao _apiConfigDao;
  final _random = Random();
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    final db = DatabaseService();
    _contactDao = ContactDao(db);
    _momentDao = MomentDao(db);
    _apiConfigDao = ApiConfigDao(db);
  }

  Future<List<Moment>> getAllMoments({int? limit, int? offset}) {
    init();
    return _momentDao.getAll(limit: limit, offset: offset);
  }

  Future<void> toggleLike(String momentId, String userId) async {
    init();
    final moments = await _momentDao.getAll();
    final moment = moments.where((m) => m.id == momentId).firstOrNull;
    if (moment == null) return;
    if (moment.likes.contains(userId)) {
      await _momentDao.removeLike(momentId, userId);
    } else {
      await _momentDao.addLike(momentId, userId);
      ExtensionEventBus.instance.publishType(
        'moment_liked',
        payload: {'momentId': momentId, 'userId': userId},
        contactId: moment.contactId,
      );
    }
  }

  Future<void> addComment(String momentId, MomentComment comment) async {
    init();
    await _momentDao.addComment(momentId, comment);
    final moments = await _momentDao.getAll();
    final moment = moments.where((m) => m.id == momentId).firstOrNull;
    ExtensionEventBus.instance.publishType(
      'moment_commented',
      payload: {
        'momentId': momentId,
        'authorId': comment.authorId,
        'content': comment.content,
      },
      contactId: moment?.contactId,
    );
  }

  Future<String?> generateAiReply(
    String momentId,
    String userComment,
    Contact contact,
  ) async {
    init();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return null;

    var config = configs.first;
    if (contact.apiConfigId != null) {
      config =
          configs.where((c) => c.id == contact.apiConfigId).firstOrNull ??
          config;
    }

    final systemPrompt = '''${contact.systemPrompt}

有人在你的朋友圈评论了你，请你回复这条评论。
要求：
- 简短自然，像真人回复评论一样
- 1-2句话
- 符合你的角色性格
- 直接输出回复内容''';

    final service = LlmService.fromConfig(config);
    try {
      final reply = await service.sendMessage(
        config: config,
        messages: [
          Message(
            id: 'comment',
            contactId: contact.id,
            role: MessageRole.user,
            content: userComment,
          ),
        ],
        systemPrompt: systemPrompt,
      );
      return reply.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> generateMomentsForAllContacts() async {
    init();
    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    for (final contact in contacts) {
      if (!contact.proactiveEnabled) continue;
      if (contact.systemPrompt.isEmpty && contact.characterCardJson == null) {
        continue;
      }
      if (_random.nextDouble() > 0.4) continue;

      await _generateMomentForContact(contact, configs);
    }
  }

  Future<void> _generateMomentForContact(Contact contact, List configs) async {
    var config = configs.first;
    if (contact.apiConfigId != null) {
      config =
          configs.where((c) => c.id == contact.apiConfigId).firstOrNull ??
          config;
    }

    final momentTypes = [
      '分享一下你的日常生活',
      '发一条感悟或心情',
      '分享你正在做的一件事',
      '分享一个有趣的想法',
      '分享你对某件事的看法',
      '记录一个美好的瞬间',
    ];
    final selectedType = momentTypes[_random.nextInt(momentTypes.length)];

    final systemPrompt =
        '''${contact.systemPrompt}

你现在要发一条朋友圈动态。
请你$selectedType。
要求：
- 像真人发朋友圈一样自然
- 2-5句话
- 可以带一些情绪和个人色彩
- 符合你的角色性格
- 直接输出朋友圈文字内容，不要加任何前缀或引号''';

    final service = LlmService.fromConfig(config);
    try {
      final content = await service.sendMessage(
        config: config,
        messages: [
          Message(
            id: 'gen',
            contactId: contact.id,
            role: MessageRole.user,
            content: '发一条朋友圈吧',
          ),
        ],
        systemPrompt: systemPrompt,
      );

      if (content.trim().isEmpty) return;

      final moment = await _momentDao.insert(
        Moment(
          id: '',
          contactId: contact.id,
          content: content.trim(),
          createdAt: DateTime.now(),
        ),
      );
      ExtensionEventBus.instance.publishType(
        'moment_created',
        payload: {'momentId': moment.id, 'content': moment.content},
        contactId: contact.id,
      );
    } catch (_) {}
  }
}
