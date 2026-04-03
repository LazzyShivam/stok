import 'user_model.dart';
import 'message_model.dart';

class ConversationMember {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime? lastReadAt;
  final UserModel? user;

  const ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.lastReadAt,
    this.user,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    return ConversationMember(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      userId: json['userId'] as String,
      lastReadAt: json['lastReadAt'] != null ? DateTime.tryParse(json['lastReadAt'] as String) : null,
      user: json['user'] != null ? UserModel.fromJson(json['user'] as Map<String, dynamic>) : null,
    );
  }
}

class ConversationModel {
  final String id;
  final List<ConversationMember> members;
  final List<MessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.members,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((m) => ConversationMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  UserModel? getOtherUser(String myUserId) {
    try {
      final others = members.where((m) => m.userId != myUserId).toList();
      if (others.isEmpty && members.isNotEmpty) return members.first.user;
      if (others.isEmpty) return null;
      // Return user if populated, else create a minimal one from member data
      return others.first.user ?? UserModel(
        id: others.first.userId,
        phone: '',
        name: 'User',
        isAgent: false,
      );
    } catch (_) {
      return null;
    }
  }

  MessageModel? get lastMessage => messages.isNotEmpty ? messages.last : null;
}
