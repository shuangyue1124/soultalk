// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String,
      contactId: json['contactId'] as String,
      role: $enumDecode(_$MessageRoleEnumMap, json['role']),
      content: json['content'] as String,
      type:
          $enumDecodeNullable(_$MessageTypeEnumMap, json['type']) ??
          MessageType.text,
      isStreaming: json['isStreaming'] as bool? ?? false,
      tokenCount: (json['tokenCount'] as num?)?.toInt() ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'contactId': instance.contactId,
      'role': _$MessageRoleEnumMap[instance.role]!,
      'content': instance.content,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'isStreaming': instance.isStreaming,
      'tokenCount': instance.tokenCount,
      'metadata': instance.metadata,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.assistant: 'assistant',
  MessageRole.system: 'system',
};

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.file: 'file',
  MessageType.transfer: 'transfer',
  MessageType.delivery: 'delivery',
  MessageType.system: 'system',
};
