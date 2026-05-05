import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../database/contact_dao.dart';
import '../database/message_dao.dart';
import '../database/api_config_dao.dart';
import '../database/memory_card_dao.dart';
import '../database/memory_entry_dao.dart';
import '../database/memory_state_dao.dart';
import '../database/regex_script_dao.dart';
import '../api/llm_service.dart';
import '../api/openai_adapter.dart';
import '../api/anthropic_adapter.dart';
import '../api/context_manager.dart';
import '../api/prompt_assembly_service.dart';
import '../memory/memory_service.dart';
import '../regex/regex_service.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../../models/regex_script.dart';

class ChatService {
  late final ContactDao _contactDao;
  late final MessageDao _messageDao;
  late final ApiConfigDao _apiConfigDao;
  late final MemoryEntryDao _memoryDao;
  late final MemoryStateDao _stateDao;
  late final MemoryCardDao _cardDao;
  late final MemoryService _memoryService;
  late final RegexScriptDao _regexScriptDao;
  final _uuid = const Uuid();
  final _contextManager = const ContextManager(
    strategy: ContextStrategy.slidingWindow,
    maxMessages: 20,
  );
  final _regexService = const RegexService();
  final _promptAssemblyService = PromptAssemblyService();

  ChatService() {
    final db = DatabaseService();
    _contactDao = ContactDao(db);
    _messageDao = MessageDao(db);
    _apiConfigDao = ApiConfigDao(db);
    _memoryDao = MemoryEntryDao(db);
    _stateDao = MemoryStateDao(db);
    _cardDao = MemoryCardDao(db);
    _memoryService = MemoryService(_memoryDao, _stateDao, _cardDao);
    _memoryService.setMessageDao(_messageDao);
    _regexScriptDao = RegexScriptDao(db);
  }

  Future<List<Contact>> getContacts() => _contactDao.getAll();

  Future<Contact?> getContact(String id) => _contactDao.getById(id);

  Future<Contact> createContact(Contact contact) => _contactDao.insert(contact);

  Future<void> updateContact(Contact contact) => _contactDao.update(contact);

  Future<void> deleteContact(String id) async {
    final db = await DatabaseService().database;
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'contact_id = ?', whereArgs: [id]);
      await txn.delete('contacts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Contact>> searchContacts(String query) =>
      _contactDao.search(query);

  Future<List<Message>> getMessages(String contactId) =>
      _messageDao.getByContact(contactId);

  Future<Message> saveMessage(Message message) async {
    final saved = await _messageDao.insert(message);
    await _contactDao.updateLastMessage(
      message.contactId,
      message.content,
      DateTime.now(),
    );
    return saved;
  }

  Future<void> deleteMessage(String messageId) => _messageDao.delete(messageId);

  Future<void> deleteMessages(String contactId) =>
      _messageDao.deleteByContact(contactId);

  Future<void> retractMessage(String messageId, String newContent) =>
      _messageDao.updateTypeAndContent(
        messageId,
        MessageType.system.name,
        newContent,
      );

  Future<List<ApiConfig>> getApiConfigs() => _apiConfigDao.getAll();

  Future<ApiConfig> createApiConfig(ApiConfig config) =>
      _apiConfigDao.insert(config);

  Future<void> updateApiConfig(ApiConfig config) =>
      _apiConfigDao.update(config);

  Future<void> deleteApiConfig(String id) => _apiConfigDao.delete(id);

  Future<void> sendMessage({
    required Contact contact,
    required String userText,
    required void Function(Message userMsg, Message aiMsg) onMessagesCreated,
    required void Function(String content, bool isDone) onAiChunk,
    void Function(String error)? onError,
  }) async {
    ApiConfig? config;
    if (contact.apiConfigId != null) {
      config = await _apiConfigDao.getById(contact.apiConfigId!);
    }
    if (config == null) {
      final configs = await _apiConfigDao.getAll();
      if (configs.isEmpty) {
        onError?.call('未配置 API，请先在设置中添加 API 配置');
        return;
      }
      config = configs.first;
    }

    final regexScripts = await _regexScriptDao.getEnabled();

    String processedUserText = _regexService.applyScripts(
      userText,
      regexScripts,
      RegexPlacement.userInput,
    );

    final userMsg = await _messageDao.insert(
      Message(
        id: '',
        contactId: contact.id,
        role: MessageRole.user,
        content: processedUserText,
        createdAt: DateTime.now(),
      ),
    );

    await _contactDao.updateLastMessage(
      contact.id,
      processedUserText,
      DateTime.now(),
    );

    final aiMsgId = _uuid.v4();
    final aiMsgPlaceholder = await _messageDao.insert(
      Message(
        id: aiMsgId,
        contactId: contact.id,
        role: MessageRole.assistant,
        content: '',
        isStreaming: true,
        createdAt: DateTime.now().add(const Duration(milliseconds: 1)),
      ),
    );

    onMessagesCreated(userMsg, aiMsgPlaceholder);

    final history = await _messageDao.getRecentByContact(contact.id, 40);
    final contextMessages = _contextManager.trim(
      history.where((m) => !m.isStreaming).toList(),
      config,
    );

    final assembled = await _promptAssemblyService.assemble(
      contact: contact,
      history: history.where((m) => !m.isStreaming).toList(),
    );
    String? systemPrompt = assembled.systemPrompt;

    // ── Memory pipeline: before request ──────────────────────────────
    try {
      final memoryResult = await _memoryService.beforeRequest(
        contactId: contact.id,
        userText: processedUserText,
        messages: contextMessages
            .map(
              (m) => {
                'role': m.role == MessageRole.user ? 'user' : 'assistant',
                'content': m.content,
              },
            )
            .toList(),
      );
      if (memoryResult.stateText != null || memoryResult.cardText != null) {
        final memoryContext = [
          if (memoryResult.stateText != null) memoryResult.stateText!,
          if (memoryResult.cardText != null) memoryResult.cardText!,
        ].join('\n\n');
        systemPrompt = systemPrompt != null
            ? '$systemPrompt\n\n$memoryContext'
            : memoryContext;
      }
    } catch (_) {
      // Memory pipeline failure must not block chat
    }

    final LlmService service = config.provider == LlmProvider.anthropic
        ? AnthropicAdapterImpl()
        : OpenAiAdapterImpl();

    final buffer = StringBuffer();
    final reasoningBuf = StringBuffer();
    try {
      await for (final chunk in service.sendMessageStream(
        config: config,
        messages: contextMessages,
        systemPrompt: systemPrompt,
      )) {
        // Reasoning content must not enter the display buffer
        if (chunk.startsWith('\x00__R__\x00')) {
          reasoningBuf.write(chunk.substring('\x00__R__\x00'.length));
          continue;
        }
        buffer.write(chunk);
        await _messageDao.updateContent(
          aiMsgId,
          buffer.toString(),
          isStreaming: true,
        );
        onAiChunk(buffer.toString(), false);
      }

      String finalAiContent = buffer.toString();

      // Separate memory markers from user-visible content
      final stripped = MemoryService.stripMemoryMarkers(finalAiContent);
      String displayContent = stripped.displayText;
      displayContent = _regexService.applyScripts(
        displayContent,
        regexScripts,
        RegexPlacement.aiOutput,
      );

      await _messageDao.updateContent(
        aiMsgId,
        displayContent,
        isStreaming: false,
      );
      // Store reasoning as message metadata for collapsible display
      final reasoningText = reasoningBuf.toString();
      if (reasoningText.isNotEmpty) {
        await _messageDao.updateMetadata(
          aiMsgId,
          jsonEncode({'reasoning_content': reasoningText}),
        );
      }
      onAiChunk(displayContent, true);

      await _contactDao.updateLastMessage(
        contact.id,
        displayContent,
        DateTime.now(),
      );

      // ── Memory pipeline: after response (uses raw content with markers) ─
      try {
        await _memoryService.afterResponse(
          contactId: contact.id,
          aiResponse: finalAiContent,
        );
      } catch (_) {}

      _tryExtractMemory(contact, config);
    } catch (e) {
      // Keep AI message empty so UI can detect failure and offer retry
      await _messageDao.updateContent(aiMsgId, '', isStreaming: false);
      onError?.call(e.toString());
    }
  }

  Future<void> clearUnread(String contactId) =>
      _contactDao.clearUnread(contactId);

  Future<void> _tryExtractMemory(Contact contact, ApiConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryEnabled = prefs.getBool('memory_enabled') ?? false;
      if (!memoryEnabled) return;

      final interval = prefs.getInt('memory_interval') ?? 10;
      final messages = await _messageDao.getRecentByContact(
        contact.id,
        interval * 2,
      );
      final userMsgCount = messages
          .where((m) => m.role == MessageRole.user)
          .length;
      if (userMsgCount < interval) return;

      final lastExtractKey = 'memory_last_extract_count_${contact.id}';
      final lastCount = prefs.getInt(lastExtractKey) ?? 0;
      final currentCount = await _messageDao.countByContact(contact.id);
      if (currentCount - lastCount < interval) return;

      await prefs.setInt(lastExtractKey, currentCount);

      final useMainApi = prefs.getBool('memory_use_main_api') ?? true;
      ApiConfig memoryConfig = config;
      if (!useMainApi) {
        final configs = await _apiConfigDao.getAll();
        if (configs.length >= 2) {
          memoryConfig = configs[1];
        }
      }

      await _memoryService.extractMemories(
        contactId: contact.id,
        apiConfig: memoryConfig,
      );
    } catch (_) {}
  }
}
