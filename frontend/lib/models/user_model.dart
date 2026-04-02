enum UserStatus { online, offline, away }

class UserModel {
  final String id;
  final String phone;
  final String name;
  final String? avatar;
  final String? bio;
  final bool isAgent;
  final Map<String, dynamic>? agentConfig;
  final UserStatus status;
  final DateTime? lastSeen;

  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    this.avatar,
    this.bio,
    this.isAgent = false,
    this.agentConfig,
    this.status = UserStatus.offline,
    this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      isAgent: json['isAgent'] as bool? ?? false,
      agentConfig: json['agentConfig'] as Map<String, dynamic>?,
      status: _statusFromString(json['status'] as String?),
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'avatar': avatar,
        'bio': bio,
        'isAgent': isAgent,
        'agentConfig': agentConfig,
        'status': status.name.toUpperCase(),
        'lastSeen': lastSeen?.toIso8601String(),
      };

  UserModel copyWith({
    String? name,
    String? avatar,
    String? bio,
    UserStatus? status,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id,
      phone: phone,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isAgent: isAgent,
      agentConfig: agentConfig,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  static UserStatus _statusFromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'ONLINE': return UserStatus.online;
      case 'AWAY': return UserStatus.away;
      default: return UserStatus.offline;
    }
  }
}
