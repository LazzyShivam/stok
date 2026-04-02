import 'user_model.dart';

enum GroupRole { owner, admin, member }

class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final GroupRole role;
  final UserModel? user;

  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    this.user,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      role: _roleFromString(json['role'] as String?),
      user: json['user'] != null ? UserModel.fromJson(json['user'] as Map<String, dynamic>) : null,
    );
  }

  static GroupRole _roleFromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'OWNER': return GroupRole.owner;
      case 'ADMIN': return GroupRole.admin;
      default: return GroupRole.member;
    }
  }
}

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? avatar;
  final String creatorId;
  final List<GroupMemberModel> members;
  final int memberCount;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.creatorId,
    required this.members,
    required this.memberCount,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      creatorId: json['creatorId'] as String,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((m) => GroupMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      memberCount: (json['_count'] as Map<String, dynamic>?)?['members'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
