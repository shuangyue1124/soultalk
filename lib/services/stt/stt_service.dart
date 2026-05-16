import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/voice_config.dart';

class SttService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  Future<String> transcribe(SttConfig config, String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw StateError('录音文件不存在');
    }

    final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _dio.post<Map<String, dynamic>>(
      '$base/audio/transcriptions',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioPath,
          filename: audioPath.split(Platform.pathSeparator).last,
        ),
        'model': config.model,
        if (config.language.trim().isNotEmpty)
          'language': config.language.trim(),
      }),
      options: Options(headers: {'Authorization': 'Bearer ${config.apiKey}'}),
    );

    final text = response.data?['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw StateError('语音识别结果为空');
    }
    return text.trim();
  }
}
