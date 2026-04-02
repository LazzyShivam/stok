import 'user_model.dart';

class BroadcastModel {
  final String id;
  final String channelId;
  final String senderId;
  final String? content;
  final String? mediaUrl;
  final String type;
  final UserModel? sender;
  final DateTime createdAt;

  const BroadcastModel({
    required this.id,
    required this.channelId,
    required this.senderId,
    this.content,
    this.mediaUrl,
    required this.type,
    this.sender,
    required this.createdAt,
  });

  factory BroadcastModel.fromJson(Map<String, dynamic> json) {
    return BroadcastModel(
      id: json['id'] as String,
      channelId: json['channelId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      type: json['type'] as String? ?? 'TEXT',
      sender: json['sender'] != null ? UserModel.fromJson(json['sender'] as Map<String, dynamic>) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ChannelModel {
  final String id;
  final String name;
  final String? description;
  final String? avatar;
  final bool isPublic;
  final String creatorId;
  final int memberCount;
  final int broadcastCount;
  final bool isJoined;
  final DateTime createdAt;

  const ChannelModel({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.isPublic,
    required this.creatorId,
    required this.memberCount,
    required this.broadcastCount,
    required this.isJoined,
    required this.createdAt,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
      creatorId: json['creatorId'] as String,
      memberCount: (json['_count'] as Map<String, dynamic>?)?['members'] as int? ?? 0,
      broadcastCount: (json['_count'] as Map<String, dynamic>?)?['broadcasts'] as int? ?? 0,
      isJoined: json['isJoined'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
