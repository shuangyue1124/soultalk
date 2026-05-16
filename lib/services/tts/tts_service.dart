import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/voice_config.dart';

class TtsService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// Synthesize speech and return path to temporary audio file.
  /// Returns null on any failure so callers can silently fall back.
  Future<String?> synthesize(TtsConfig config, String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final bytes = await _requestTts(config, text);
      final dir = await getTemporaryDirectory();
      final ext = config.audioFormat.isNotEmpty ? config.audioFormat : 'mp3';
      final file = File(
        '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _requestTts(TtsConfig config, String text) async {
    final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    String url;
    Map<String, dynamic> data;

    if (config.provider == TtsProvider.openai ||
        config.provider == TtsProvider.azure ||
        config.provider == TtsProvider.edge) {
      // OpenAI-compatible TTS: POST /v1/audio/speech with "input" field
      url = '$base/audio/speech';
      data = {
        'model': config.model,
        'input': text,
        'voice': config.voice,
        'speed': config.speed,
        'response_format': config.audioFormat,
      };
    } else if (config.provider == TtsProvider.elevenlabs) {
      // ElevenLabs: POST /v1/text-to-speech/{voice_id}
      url = '$base/text-to-speech/${config.voice}';
      data = {'text': text, 'model_id': config.model};
    } else {
      // Custom / MiMo: chat-like format with messages
      // MiMo API expects text in role:assistant messages
      url = '$base/audio/speech';
      data = {
        'model': config.model,
        'messages': [
          {'role': 'assistant', 'content': text},
        ],
        'voice': config.voice,
        'response_format': config.audioFormat,
      };
    }

    final response = await _dio.post(
      url,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
      ),
      data: data,
    );
    return response.data as Uint8List;
  }

  /// Strip memory markers so internal instructions are never spoken.
  static String stripMemoryMarkers(String text) {
    return text
        .replaceAll(
          RegExp(
            r'\n?\[MEMORY:\w+\]\s*.+?(?:\(importance:[\s\S]+?\))\n?',
            multiLine: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\n?\[STATE:\w+\]\s*.+?(?:\(confidence:[\s\S]+?\))\n?',
            multiLine: true,
          ),
          '',
        )
        .trim();
  }
}
