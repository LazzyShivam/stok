import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

typedef SocketEventCallback = void Function(dynamic data);

class SocketService {
  io.Socket? _socket;
  final Map<String, List<SocketEventCallback>> _listeners = {};

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket?.connected == true) return;

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      print('[Socket] Connected');
      _reattachListeners();
    });

    _socket!.onDisconnect((_) => print('[Socket] Disconnected'));
    _socket!.onConnectError((e) => print('[Socket] Connection error: $e'));
    _socket!.onError((e) => print('[Socket] Error: $e'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, SocketEventCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, callback);
  }

  void off(String event, [SocketEventCallback? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
      _socket?.off(event, callback);
    } else {
      _listeners.remove(event);
      _socket?.off(event);
    }
  }

  void _reattachListeners() {
    _listeners.forEach((event, callbacks) {
      for (final cb in callbacks) {
        _socket?.on(event, cb);
      }
    });
  }

  // Convenience methods
  void joinConversation(String convId) => emit('join_conversation', convId);
  void leaveConversation(String convId) => emit('leave_conversation', convId);

  void sendTypingStart(String convId) => emit('typing_start', {'conversationId': convId});
  void sendTypingStop(String convId) => emit('typing_stop', {'conversationId': convId});

  void sendGroupTypingStart(String groupId) => emit('group_typing_start', {'groupId': groupId});
  void sendGroupTypingStop(String groupId) => emit('group_typing_stop', {'groupId': groupId});

  void markRead(String convId) => emit('mark_read', {'conversationId': convId});

  void sendMessage({
    required String conversationId,
    required String content,
    String type = 'TEXT',
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) {
    emit('send_message', {
      'conversationId': conversationId,
      'content': content,
      'type': type,
      if (replyToId != null) 'replyToId': replyToId,
      if (metadata != null) 'metadata': metadata,
    });
  }

  void sendGroupMessage({
    required String groupId,
    required String content,
    String type = 'TEXT',
    String? replyToId,
  }) {
    emit('send_group_message', {
      'groupId': groupId,
      'content': content,
      'type': type,
      if (replyToId != null) 'replyToId': replyToId,
    });
  }

  // WebRTC signaling
  void sendOffer(String targetUserId, String callId, Map<String, dynamic> offer) {
    emit('webrtc_offer', {'targetUserId': targetUserId, 'callId': callId, 'offer': offer});
  }

  void sendAnswer(String targetUserId, String callId, Map<String, dynamic> answer) {
    emit('webrtc_answer', {'targetUserId': targetUserId, 'callId': callId, 'answer': answer});
  }

  void sendIceCandidate(String targetUserId, String callId, Map<String, dynamic> candidate) {
    emit('ice_candidate', {'targetUserId': targetUserId, 'callId': callId, 'candidate': candidate});
  }

  void hangup(String targetUserId, String callId) {
    emit('call_hangup', {'targetUserId': targetUserId, 'callId': callId});
  }

  void rejectCall(String targetUserId, String callId) {
    emit('call_reject', {'targetUserId': targetUserId, 'callId': callId});
  }

  void updateStatus(String status) => emit('update_status', {'status': status});
}
