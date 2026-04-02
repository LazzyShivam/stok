import 'user_model.dart';

enum AttendeeStatus { pending, accepted, declined }

class EventAttendeeModel {
  final String id;
  final String eventId;
  final String userId;
  final AttendeeStatus status;
  final UserModel? user;

  const EventAttendeeModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    this.user,
  });

  factory EventAttendeeModel.fromJson(Map<String, dynamic> json) {
    return EventAttendeeModel(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      userId: json['userId'] as String,
      status: _statusFromString(json['status'] as String?),
      user: json['user'] != null ? UserModel.fromJson(json['user'] as Map<String, dynamic>) : null,
    );
  }

  static AttendeeStatus _statusFromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'ACCEPTED': return AttendeeStatus.accepted;
      case 'DECLINED': return AttendeeStatus.declined;
      default: return AttendeeStatus.pending;
    }
  }
}

class EventModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? meetLink;
  final String creatorId;
  final String? groupId;
  final String? channelId;
  final List<EventAttendeeModel> attendees;
  final UserModel? creator;
  final int attendeeCount;
  final AttendeeStatus? myStatus;
  final DateTime createdAt;

  const EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.meetLink,
    required this.creatorId,
    this.groupId,
    this.channelId,
    required this.attendees,
    this.creator,
    required this.attendeeCount,
    this.myStatus,
    required this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json, {String? myUserId}) {
    final attendees = (json['attendees'] as List<dynamic>? ?? [])
        .map((a) => EventAttendeeModel.fromJson(a as Map<String, dynamic>))
        .toList();

    AttendeeStatus? myStatus;
    if (myUserId != null) {
      final mine = attendees.where((a) => a.userId == myUserId).toList();
      if (mine.isNotEmpty) myStatus = mine.first.status;
    }

    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      meetLink: json['meetLink'] as String?,
      creatorId: json['creatorId'] as String,
      groupId: json['groupId'] as String?,
      channelId: json['channelId'] as String?,
      attendees: attendees,
      creator: json['creator'] != null ? UserModel.fromJson(json['creator'] as Map<String, dynamic>) : null,
      attendeeCount: (json['_count'] as Map<String, dynamic>?)?['attendees'] as int? ?? attendees.length,
      myStatus: myStatus,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isUpcoming => startTime.isAfter(DateTime.now());
  bool get isOngoing => DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);
}
