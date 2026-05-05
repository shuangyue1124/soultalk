// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ApiConfigImpl _$$ApiConfigImplFromJson(Map<String, dynamic> json) =>
    _$ApiConfigImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      provider:
          $enumDecodeNullable(_$LlmProviderEnumMap, json['provider']) ??
          LlmProvider.openai,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      model: json['model'] as String? ?? 'gpt-4o-mini',
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 4096,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.8,
      streamEnabled: json['streamEnabled'] as bool? ?? true,
      thinkingEnabled: json['thinkingEnabled'] as bool? ?? false,
      reasoningEffort: json['reasoningEffort'] as String? ?? 'high',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ApiConfigImplToJson(_$ApiConfigImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'provider': _$LlmProviderEnumMap[instance.provider]!,
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'model': instance.model,
      'maxTokens': instance.maxTokens,
      'temperature': instance.temperature,
      'streamEnabled': instance.streamEnabled,
      'thinkingEnabled': instance.thinkingEnabled,
      'reasoningEffort': instance.reasoningEffort,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$LlmProviderEnumMap = {
  LlmProvider.openai: 'openai',
  LlmProvider.anthropic: 'anthropic',
  LlmProvider.custom: 'custom',
};
