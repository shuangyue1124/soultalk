import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/api_config.dart';
import '../../models/message.dart';
import 'llm_service.dart';

class AnthropicAdapterImpl implements LlmService {
  static const String _defaultBaseUrl = 'https://api.anthropic.com';
  static const String _anthropicVersion = '2023-06-01';

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  String _normalizeUrl(String url) {
    final base = url.isNotEmpty ? url : _defaultBaseUrl;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Map<String, String> _headers(ApiConfig config) => {
    'x-api-key': config.apiKey,
    'anthropic-version': _anthropicVersion,
    'Content-Type': 'application/json',
  };

  List<Map<String, String>> _buildMessages(List<Message> messages) {
    return LlmService.toApiMessages(messages);
  }

  @override
  Future<String> sendMessage({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
  }) async {
    final baseUrl = _normalizeUrl(config.baseUrl);
    final body = <String, dynamic>{
      'model': config.model,
      'max_tokens': config.maxTokens,
      'messages': _buildMessages(messages),
    };
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }
    if (config.thinkingEnabled) {
      body['output_config'] = {'effort': config.reasoningEffort};
    }

    final response = await _dio.post(
      '$baseUrl/v1/messages',
      data: body,
      options: Options(headers: _headers(config)),
    );
    final data = response.data as Map<String, dynamic>;
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) {
      throw Exception('API 返回了空的 content');
    }
    final firstBlock = content.first as Map<String, dynamic>?;
    return (firstBlock?['text'] as String?) ?? '';
  }

  @override
  Stream<String> sendMessageStream({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
  }) async* {
    final baseUrl = _normalizeUrl(config.baseUrl);
    final streamDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    final body = <String, dynamic>{
      'model': config.model,
      'max_tokens': config.maxTokens,
      'messages': _buildMessages(messages),
      'stream': true,
    };
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }
    if (config.thinkingEnabled) {
      body['output_config'] = {'effort': config.reasoningEffort};
    }

    final response = await streamDio.post<ResponseBody>(
      '$baseUrl/v1/messages',
      data: body,
      options: Options(
        headers: _headers(config),
        responseType: ResponseType.stream,
      ),
    );

    if (response.data == null) {
      throw Exception('API 流式响应为空');
    }

    final lineBuffer = StringBuffer();
    await for (final chunk in response.data!.stream) {
      lineBuffer.write(utf8.decode(chunk, allowMalformed: true));

      final raw = lineBuffer.toString();
      final lastNl = raw.lastIndexOf('\n');
      if (lastNl < 0) continue;

      final completeLines = raw.substring(0, lastNl + 1);
      lineBuffer.clear();
      lineBuffer.write(raw.substring(lastNl + 1));

      for (final line in completeLines.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final jsonStr = trimmed.substring(6).trim();
        if (jsonStr == '[DONE]') return;
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'content_block_delta') {
            final delta = json['delta'] as Map<String, dynamic>?;
            final text = delta?['text'] as String?;
            if (text != null && text.isNotEmpty) {
              yield text;
            }
          }
        } catch (_) {}
      }
    }
  }
}
