import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

enum MessageRole { user, assistant, system }

enum MessageType {
  text,
  image,
  file,
  transfer, // 虚拟转账
  delivery, // 虚拟外卖
  system, // 系统消息
}

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String contactId,
    required MessageRole role,
    required String content,
    @Default(MessageType.text) MessageType type,
    @Default(false) bool isStreaming,
    @Default(0) int tokenCount,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
