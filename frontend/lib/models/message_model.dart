import 'user_model.dart';

enum MessageType { text, image, video, audio, voice, file, eventCard, system, aiResponse }

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final MessageType type;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
  final bool isDeleted;
  final String? replyToId;
  final MessageModel? replyTo;
  final UserModel? sender;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.metadata,
    this.isDeleted = false,
    this.replyToId,
    this.replyTo,
    this.sender,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String?,
      type: _typeFromString(json['type'] as String?),
      mediaUrl: json['mediaUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      replyToId: json['replyToId'] as String?,
      replyTo: json['replyTo'] != null ? MessageModel.fromJson(json['replyTo'] as Map<String, dynamic>) : null,
      sender: json['sender'] != null ? UserModel.fromJson(json['sender'] as Map<String, dynamic>) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static MessageType _typeFromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'IMAGE': return MessageType.image;
      case 'VIDEO': return MessageType.video;
      case 'AUDIO': return MessageType.audio;
      case 'VOICE': return MessageType.voice;
      case 'FILE': return MessageType.file;
      case 'EVENT_CARD': return MessageType.eventCard;
      case 'SYSTEM': return MessageType.system;
      case 'AI_RESPONSE': return MessageType.aiResponse;
      default: return MessageType.text;
    }
  }

  bool get isMedia => [MessageType.image, MessageType.video, MessageType.audio, MessageType.voice, MessageType.file].contains(type);
  bool get isVoice => type == MessageType.voice;
  bool get isImage => type == MessageType.image;
}
