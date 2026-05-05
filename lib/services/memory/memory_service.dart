import 'package:soultalk/platform/platform_config.dart';
import '../../models/memory_card.dart';
import '../../models/api_config.dart';
import '../../models/memory_entry.dart';
import '../../models/memory_state.dart';
import '../../models/message.dart';
import '../api/llm_service.dart';
import '../database/memory_card_dao.dart';
import '../database/memory_entry_dao.dart';
import '../database/memory_state_dao.dart';
import '../database/message_dao.dart';
import 'state_renderer.dart';
import 'state_injector.dart';
import 'retrieval_gate.dart';
import 'card_retriever.dart';
import 'card_injector.dart';
import 'state_filler.dart';
import 'card_extractor.dart';
import 'review_policy.dart';

/// Three-tier memory pipeline orchestrator.
///
/// Pipeline:
///   beforeRequest(): state render → state inject → gate → [retrieve → card inject]
///   afterResponse():  state fill → card extract → review → insert
class MemoryService {
  final MemoryEntryDao _memoryDao;
  final MemoryStateDao _stateDao;
  final MemoryCardDao _cardDao;
  MessageDao? _messageDao;

  final StateRenderer _stateRenderer;
  final StateInjector _stateInjector;
  final RetrievalGate _retrievalGate;
  final CardRetriever _cardRetriever;
  final CardInjector _cardInjector;
  final StateFiller _stateFiller;
  final CardExtractor _cardExtractor;
  final ReviewPolicy _reviewPolicy;

  MemoryService(
    this._memoryDao,
    this._stateDao,
    this._cardDao, {
    PlatformConfig? config,
  }) : _stateRenderer = StateRenderer(config),
       _stateInjector = const StateInjector(),
       _retrievalGate = RetrievalGate(config: config),
       _cardRetriever = CardRetriever(_cardDao, config),
       _cardInjector = const CardInjector(),
       _stateFiller = StateFiller(_stateDao),
       _cardExtractor = CardExtractor(),
       _reviewPolicy = ReviewPolicy(config);

  /// Set the message DAO for LLM-based memory extraction.
  void setMessageDao(MessageDao dao) => _messageDao = dao;

  // ── Pipeline: before request ─────────────────────────────────────

  /// Process messages before they are sent to the LLM.
  ///
  /// Returns the (possibly augmented) message list with state board
  /// and relevant memory cards injected.
  Future<BeforeRequestResult> beforeRequest({
    required String contactId,
    required String userText,
    required List<Map<String, dynamic>> messages,
    int? turnIndex,
  }) async {
    var augmented = messages;

    // 1. Render + inject state board
    final states = await _stateDao.getByContact(contactId);
    final stateText = _stateRenderer.render(states);
    if (stateText.isNotEmpty) {
      augmented = _stateInjector.inject(augmented, stateText);
    }

    // 2. Retrieval gate
    final decision = _retrievalGate.decide(
      userText: userText,
      turnIndex: turnIndex,
      stateItems: states,
    );

    List<MemoryCard> retrievedCards = [];
    if (decision.shouldRetrieve) {
      // 3. Extract keywords from user text + state board
      final keywords = _extractKeywords(userText, states);
      if (keywords.isNotEmpty) {
        retrievedCards = await _cardRetriever.retrieve(contactId, keywords);
        if (retrievedCards.isNotEmpty) {
          augmented = _cardInjector.inject(augmented, retrievedCards);
        }
      }
    }

    // 4. Render cards to text block
    String? cardText;
    if (retrievedCards.isNotEmpty) {
      final buf = StringBuffer();
      buf.writeln('[相关记忆]');
      for (final card in retrievedCards) {
        buf.writeln('- ${card.content}');
      }
      cardText = buf.toString().trim();
    }

    return BeforeRequestResult(
      messages: augmented,
      gateDecision: decision,
      retrievedCardCount: retrievedCards.length,
      stateText: stateText.isNotEmpty ? stateText : null,
      cardText: cardText,
    );
  }

  // ── Pipeline: after response ──────────────────────────────────────

  /// Process AI response after it completes.
  ///
  /// Updates state board and extracts candidate memory cards.
  Future<AfterResponseResult> afterResponse({
    required String contactId,
    required String aiResponse,
  }) async {
    // 1. Fill state board from AI response
    final updatedStates = await _stateFiller.fillFromResponse(
      contactId,
      aiResponse,
    );

    // 2. Extract candidate memory cards
    final candidates = await _cardExtractor.extractFromResponse(
      contactId,
      aiResponse,
    );

    // 3. Review and insert
    var approvedCount = 0;
    var pendingCount = 0;
    var rejectedCount = 0;

    for (final card in candidates) {
      final action = _reviewPolicy.review(card);
      switch (action) {
        case ReviewAction.approve:
          await _cardDao.insert(
            card.copyWith(status: 'active', reviewedAt: DateTime.now()),
          );
          approvedCount++;
        case ReviewAction.pending:
          await _cardDao.insert(card);
          pendingCount++;
        case ReviewAction.reject:
          rejectedCount++;
      }
    }

    return AfterResponseResult(
      updatedStateCount: updatedStates.length,
      approvedCards: approvedCount,
      pendingCards: pendingCount,
      rejectedCards: rejectedCount,
    );
  }

  // ── Backward-compatible API ───────────────────────────────────────

  Future<List<MemoryEntry>> getMemories(String contactId) {
    return _memoryDao.getByContact(contactId);
  }

  Future<List<MemoryState>> getStates(String contactId) {
    return _stateDao.getByContact(contactId);
  }

  Future<List<MemoryCard>> getCards(String contactId) {
    return _cardDao.getActiveByContact(contactId);
  }

  Future<String> getMemoryPrompt(String contactId) async {
    final entries = await _memoryDao.getByContact(contactId);
    return MemoryEntry.tableToPrompt(entries);
  }

  /// Legacy extraction — uses LLM to extract memories from recent conversation.
  Future<void> extractMemories({
    required String contactId,
    required ApiConfig apiConfig,
  }) async {
    final msgDao = _messageDao;
    if (msgDao == null) return;

    final messages = await msgDao.getRecentByContact(contactId, 30);
    if (messages.length < 4) return;

    final conversationText = messages
        .where((m) => m.role != MessageRole.system)
        .map((m) =>
            '[${m.role == MessageRole.user ? "user" : "assistant"}]: ${m.content}')
        .join('\n');

    final prompt = '''从以下对话中提取关键记忆。请使用指定格式输出，每条一行：

[MEMORY:fact] 内容 (importance: 0.8, confidence: 0.9, scope: local, tags: 标签1,标签2)
[STATE:状态名] 值 (confidence: 0.8)

支持的 MEMORY 类型: fact, event, preference, boundary, relationship, character_state, world_state, roleplay_rule, speech_style, misc
支持的 scope: local, shared, global

对话:
$conversationText''';

    final service = LlmService.fromConfig(apiConfig);
    try {
      final response = await service.sendMessage(
        config: apiConfig.copyWith(
          temperature: 0.3,
          maxTokens: 2048,
          streamEnabled: false,
        ),
        messages: [
          Message(
            id: '',
            contactId: contactId,
            role: MessageRole.user,
            content: prompt,
            createdAt: DateTime.now(),
          ),
        ],
      );
      if (response.isNotEmpty) {
        await afterResponse(contactId: contactId, aiResponse: response);
      }
    } catch (_) {}
  }

  /// Split AI response into display text and memory-marker text.
  /// Memory markers ([MEMORY:...], [STATE:...]) are extracted for the
  /// memory pipeline and stripped from user-visible content.
  static StripResult stripMemoryMarkers(String text) {
    final memoryBuf = StringBuffer();
    final memRegex = RegExp(
      r'\[MEMORY:\w+\]\s*.+?\n?\)',
      multiLine: true,
    );
    final stateRegex = RegExp(
      r'\[STATE:\w+\]\s*.+?\n?\)',
      multiLine: true,
    );

    for (final m in memRegex.allMatches(text)) {
      memoryBuf.writeln(m.group(0));
    }
    for (final m in stateRegex.allMatches(text)) {
      memoryBuf.writeln(m.group(0));
    }

    var display = text;
    display = display.replaceAll(memRegex, '');
    display = display.replaceAll(stateRegex, '');
    display = display.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return StripResult(
      displayText: display,
      memoryText: memoryBuf.toString().trim(),
    );
  }

  Future<void> deleteMemory(String id) => _memoryDao.delete(id);
  Future<void> clearMemories(String contactId) =>
      _memoryDao.deleteByContact(contactId);
}

/// Result from [MemoryService.beforeRequest].
class BeforeRequestResult {
  final List<Map<String, dynamic>> messages;
  final GateDecision gateDecision;
  final int retrievedCardCount;
  final String? stateText;
  final String? cardText;

  const BeforeRequestResult({
    required this.messages,
    required this.gateDecision,
    required this.retrievedCardCount,
    this.stateText,
    this.cardText,
  });
}

/// Result from [MemoryService.afterResponse].
class AfterResponseResult {
  final int updatedStateCount;
  final int approvedCards;
  final int pendingCards;
  final int rejectedCards;

  const AfterResponseResult({
    required this.updatedStateCount,
    required this.approvedCards,
    required this.pendingCards,
    required this.rejectedCards,
  });
}

// ── Keyword extraction helpers ──────────────────────────────────────

/// Extract retrieval keywords from user text and state board.
List<String> _extractKeywords(String userText, List<MemoryState> states) {
  final keywords = <String>{};

  // Simple keyword extraction: split by common delimiters, filter short/noise words
  final noise = {
    '的',
    '了',
    '是',
    '在',
    '我',
    '你',
    '他',
    '她',
    '它',
    '们',
    '这',
    '那',
    '和',
    '与',
    '或',
    '吗',
    '呢',
    '吧',
    '啊',
    '哦',
    '嗯',
    '哈',
    '都',
    '也',
    '就',
    '要',
    '会',
    '能',
    '不',
    '很',
    '想',
    '说',
    '去',
    '来',
    '有',
    '看',
    '让',
    '把',
    '被',
    '对',
    '从',
    '到',
    '为',
    '以',
    '可',
    '没',
    '做',
    '知道',
    '觉得',
    '什么',
    '怎么',
    '为什么',
    '哪里',
    '可以',
    '应该',
    '如果',
    '因为',
    '所以',
    '但是',
    '虽然',
    '不过',
    '然后',
    '还有',
    '一个',
    '这个',
    '那个',
    '我的',
    '你的',
    '他的',
  };

  // Extract from user text
  final splitPattern = RegExp(r'[^\w一-鿿]+');
  for (final word in userText.split(splitPattern)) {
    final trimmed = word.trim();
    if (trimmed.length >= 2 && !noise.contains(trimmed)) {
      keywords.add(trimmed);
    }
  }

  // Extract from state board slot names
  for (final state in states.where((s) => s.status == 'active')) {
    keywords.add(state.slotName);
  }

  return keywords.take(10).toList();
}

class StripResult {
  final String displayText;
  final String memoryText;
  const StripResult({required this.displayText, required this.memoryText});
}
