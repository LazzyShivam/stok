import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';

class PresenceProvider extends ChangeNotifier {
  final SocketService _socket;
  final Map<String, UserStatus> _statuses = {};
  final Map<String, DateTime?> _lastSeen = {};

  PresenceProvider(this._socket) {
    _socket.on('user_status', (data) {
      if (data is Map) {
        final userId = data['userId'] as String;
        final status = _statusFromString(data['status'] as String?);
        _statuses[userId] = status;
        if (data['lastSeen'] != null) {
          _lastSeen[userId] = DateTime.tryParse(data['lastSeen'] as String);
        }
        notifyListeners();
      }
    });

    _socket.on('presence_list', (data) {
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final userId = item['id'] as String;
            _statuses[userId] = _statusFromString(item['status'] as String?);
            if (item['lastSeen'] != null) {
              _lastSeen[userId] = DateTime.tryParse(item['lastSeen'] as String);
            }
          }
        }
        notifyListeners();
      }
    });
  }

  UserStatus statusOf(String userId) => _statuses[userId] ?? UserStatus.offline;
  DateTime? lastSeenOf(String userId) => _lastSeen[userId];

  void checkPresence(List<String> userIds) {
    _socket.emit('check_presence', {'userIds': userIds});
  }

  static UserStatus _statusFromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'ONLINE': return UserStatus.online;
      case 'AWAY': return UserStatus.away;
      default: return UserStatus.offline;
    }
  }
}
