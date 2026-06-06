import 'dart:convert';
import 'dart:io';
import '../../models/character_card.dart';
import '../../models/contact.dart';
import '../regex/regex_service.dart';
import '../character/character_png_service.dart';

class ImportValidationResult {
  final bool isValid;
  final String? error;
  final String? warning;
  final Map<String, dynamic>? data;

  const ImportValidationResult({
    required this.isValid,
    this.error,
    this.warning,
    this.data,
  });

  factory ImportValidationResult.ok(
    Map<String, dynamic> data, {
    String? warning,
  }) {
    return ImportValidationResult(isValid: true, data: data, warning: warning);
  }

  factory ImportValidationResult.fail(String error) {
    return ImportValidationResult(isValid: false, error: error);
  }
}

class ImportService {
  static String _stripBom(String content) {
    if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
      return content.substring(1);
    }
    return content;
  }

  static ImportValidationResult _validateJson(String rawContent) {
    final content = _stripBom(rawContent.trim());

    if (content.isEmpty) {
      return ImportValidationResult.fail('文件内容为空');
    }

    final firstChar = content[0];
    if (firstChar != '{' && firstChar != '[') {
      return ImportValidationResult.fail(
        'JSON 格式错误：文件应以 { 或 [ 开头，实际以 "$firstChar" 开头',
      );
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return ImportValidationResult.fail('JSON 格式错误：根元素是数组，应为对象');
      }
      if (decoded is! Map<String, dynamic>) {
        return ImportValidationResult.fail('JSON 格式错误：根元素应为对象');
      }
      return ImportValidationResult.ok(decoded);
    } on FormatException catch (e) {
      final message = e.message;
      String hint = '';
      if (message.contains('Unexpected')) {
        hint = '（可能存在多余逗号、缺少引号或括号不匹配）';
      }
      return ImportValidationResult.fail('JSON 解析失败：$message$hint');
    }
  }

  static ImportValidationResult validateCharacterCard(String rawContent) {
    final jsonResult = _validateJson(rawContent);
    if (!jsonResult.isValid) return jsonResult;

    final json = jsonResult.data!;

    final dataValue = json['data'];
    if (dataValue != null && dataValue is! Map<String, dynamic>) {
      return ImportValidationResult.fail('角色卡字段 "data" 应为对象');
    }
    final data = dataValue ?? json;

    final name = data['name'] as String? ?? '';
    if (name.isEmpty) {
      return ImportValidationResult.fail('角色卡缺少必要字段 "name"（角色名称不能为空）');
    }

    final spec = json['spec'] as String?;
    final specVersion = json['spec_version'] as String?;
    String versionInfo = '';

    if (spec == 'chara_card_v3' || specVersion == '3.0') {
      versionInfo = 'V3';
    } else if (spec == 'chara_card_v2' || specVersion == '2.0') {
      versionInfo = 'V2';
    } else if (json.containsKey('data')) {
      versionInfo = 'V2（无spec标记）';
    } else {
      versionInfo = 'V1（兼容模式）';
    }

    final warnings = <String>[];
    if ((data['description'] as String? ?? '').isEmpty) {
      warnings.add('description 字段为空');
    }
    if (spec == null && !json.containsKey('data')) {
      warnings.add('未检测到 spec 字段，将以 V1 兼容模式解析');
    }

    return ImportValidationResult.ok(
      json,
      warning: warnings.isNotEmpty
          ? '格式：$versionInfo，注意：${warnings.join("；")}'
          : '格式：$versionInfo',
    );
  }

  static ImportValidationResult validateRegexScripts(String rawContent) {
    final content = _stripBom(rawContent.trim());
    if (content.isEmpty) {
      return ImportValidationResult.fail('文件内容为空');
    }

    try {
      final decoded = jsonDecode(content);
      List<Map<String, dynamic>> scriptsList;

      if (decoded is List) {
        scriptsList = decoded.whereType<Map<String, dynamic>>().toList();
      } else if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('scriptName') ||
            decoded.containsKey('findRegex')) {
          scriptsList = [decoded];
        } else {
          scriptsList = decoded.values
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      } else {
        return ImportValidationResult.fail('正则脚本文件格式错误：根元素应为对象或数组');
      }

      if (scriptsList.isEmpty) {
        return ImportValidationResult.fail('未找到有效的正则脚本条目');
      }

      final errors = <String>[];
      int validCount = 0;

      for (int i = 0; i < scriptsList.length; i++) {
        final script = scriptsList[i];
        final index = i + 1;

        final findRegex = script['findRegex'] as String? ?? '';
        if (findRegex.isEmpty) {
          errors.add('第 $index 条脚本缺少 findRegex 字段');
          continue;
        }

        if (!RegexService.validatePattern(findRegex)) {
          errors.add('第 $index 条脚本的正则表达式无效：$findRegex');
          continue;
        }

        validCount++;
      }

      if (validCount == 0) {
        return ImportValidationResult.fail('所有正则脚本均无效：\n${errors.join("\n")}');
      }

      return ImportValidationResult.ok(
        {'scripts': scriptsList},
        warning: errors.isNotEmpty
            ? '${errors.length} 条脚本有问题：\n${errors.take(3).join("\n")}'
            : null,
      );
    } on FormatException catch (e) {
      return ImportValidationResult.fail('JSON 解析失败：${e.message}');
    }
  }

  static ImportValidationResult validatePreset(String rawContent) {
    final jsonResult = _validateJson(rawContent);
    if (!jsonResult.isValid) return jsonResult;

    final json = jsonResult.data!;

    final segments = json['segments'] as List?;
    if (segments == null || segments.isEmpty) {
      final promptEntries = json['prompts'] as List?;
      if (promptEntries == null || promptEntries.isEmpty) {
        return ImportValidationResult.fail(
          '预设文件中没有找到有效的段落（segments/prompts 字段为空）',
        );
      }
    }

    return ImportValidationResult.ok(json);
  }

  static Future<ImportValidationResult> importCharacterCardFromFile(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportValidationResult.fail('文件不存在：$filePath');
      }

      final extension = filePath.split('.').last.toLowerCase();

      if (extension == 'png') {
        return _importFromPng(file);
      }

      final rawContent = await file.readAsString();
      return validateCharacterCard(rawContent);
    } catch (e) {
      return ImportValidationResult.fail('读取文件失败：$e');
    }
  }

  static Future<ImportValidationResult> _importFromPng(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final raw = CharacterPngService.extractCharaJson(bytes);
      if (raw == null) {
        return ImportValidationResult.fail(
          '该 PNG 图片中未找到嵌入的角色卡数据（tEXt/iTXt chunk 中无 "chara" 关键字）',
        );
      }
      return validateCharacterCard(raw);
    } catch (e) {
      return ImportValidationResult.fail('PNG 解析失败：$e');
    }
  }

  static Contact? buildContactFromCard(
    Map<String, dynamic> json,
    String rawJson,
  ) {
    final card = CharacterCard.fromAutoDetectJson(json);
    if (card.name.isEmpty) return null;

    return Contact(
      id: '',
      name: card.name,
      description: card.description,
      systemPrompt: card.buildSystemPrompt('用户'),
      tags: card.tags,
      characterCardJson: rawJson,
    );
  }
}
