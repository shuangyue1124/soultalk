import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/api_config.dart';
import '../../models/message.dart';
import 'llm_service.dart';

class OpenAiAdapterImpl implements LlmService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  List<Map<String, String>> _buildMessages(
    List<Message> messages,
    String? systemPrompt,
  ) {
    final result = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      result.add({'role': 'system', 'content': systemPrompt});
    }
    result.addAll(LlmService.toApiMessages(messages));
    return result;
  }

  @override
  Future<String> sendMessage({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
  }) async {
    final baseUrl = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _dio.post(
      '$baseUrl/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
      data: _buildRequestData(config, messages, systemPrompt, stream: false),
    );
    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('API 返回了空的 choices');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    return content ?? '';
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

    final response = await streamDio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.stream,
      ),
      data: _buildRequestData(config, messages, systemPrompt, stream: true),
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
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            final reasoning = delta?['reasoning_content'] as String?;
            if (reasoning != null && reasoning.isNotEmpty) {
              yield '\x00__R__\x00$reasoning';
            }
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {}
      }
    }
  }

  Map<String, dynamic> _buildRequestData(
    ApiConfig config,
    List<Message> messages,
    String? systemPrompt, {
    required bool stream,
  }) {
    final data = <String, dynamic>{
      'model': config.model,
      'messages': _buildMessages(messages, systemPrompt),
      'max_tokens': config.maxTokens,
      'stream': stream,
    };
    // Non-streaming can include temperature
    if (!stream) {
      data['temperature'] = config.temperature;
    }
    // DeepSeek thinking mode
    if (config.thinkingEnabled) {
      data['thinking'] = {'type': 'enabled'};
      data['reasoning_effort'] = config.reasoningEffort;
    }
    return data;
  }

  String _normalizeUrl(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
