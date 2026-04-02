import 'package:flutter/foundation.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/group_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  final SocketService _socket;

  List<ConversationModel> _conversations = [];
  List<GroupModel> _groups = [];
  final Map<String, List<MessageModel>> _messages = {};
  final Map<String, Set<String>> _typingUsers = {};
  bool _loading = false;

  ChatProvider(this._api, this._socket) {
    _setupSocketListeners();
  }

  List<ConversationModel> get conversations => _conversations;
  List<GroupModel> get groups => _groups;
  bool get loading => _loading;

  List<MessageModel> messagesFor(String convId) => _messages[convId] ?? [];
  Set<String> typingUsersFor(String convId) => _typingUsers[convId] ?? {};

  void _setupSocketListeners() {
    _socket.on('new_message', (data) {
      if (data is Map) {
        final msg = MessageModel.fromJson(Map<String, dynamic>.from(data as Map));
        final convId = msg.conversationId;
        _messages.putIfAbsent(convId, () => []).add(msg);
        _updateConversationLastMessage(convId, msg);
        notifyListeners();
      }
    });

    _socket.on('new_group_message', (data) {
      if (data is Map) {
        final msg = MessageModel.fromJson(Map<String, dynamic>.from(data['message'] as Map));
        final groupId = data['groupId'] as String;
        _messages.putIfAbsent('group:$groupId', () => []).add(msg);
        notifyListeners();
      }
    });

    _socket.on('message_deleted', (data) {
      if (data is Map) {
        final msgId = data['messageId'] as String;
        for (final key in _messages.keys) {
          final list = _messages[key];
          if (list != null) {
            final idx = list.indexWhere((m) => m.id == msgId);
            if (idx >= 0) {
              // Mark as deleted by removing (simplified)
              list.removeAt(idx);
              notifyListeners();
              break;
            }
          }
        }
      }
    });

    _socket.on('user_typing', (data) {
      if (data is Map) {
        final userId = data['userId'] as String;
        final convId = data['conversationId'] as String;
        _typingUsers.putIfAbsent(convId, () => {}).add(userId);
        notifyListeners();
      }
    });

    _socket.on('user_stopped_typing', (data) {
      if (data is Map) {
        final userId = data['userId'] as String;
        final convId = data['conversationId'] as String;
        _typingUsers[convId]?.remove(userId);
        notifyListeners();
      }
    });

    _socket.on('group_user_typing', (data) {
      if (data is Map) {
        final userId = data['userId'] as String;
        final groupId = data['groupId'] as String;
        _typingUsers.putIfAbsent('group:$groupId', () => {}).add(userId);
        notifyListeners();
      }
    });

    _socket.on('group_user_stopped_typing', (data) {
      if (data is Map) {
        final userId = data['userId'] as String;
        final groupId = data['groupId'] as String;
        _typingUsers['group:$groupId']?.remove(userId);
        notifyListeners();
      }
    });
  }

  void _updateConversationLastMessage(String convId, MessageModel msg) {
    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx >= 0) {
      final conv = _conversations[idx];
      final newMessages = [msg];
      _conversations[idx] = ConversationModel(
        id: conv.id,
        members: conv.members,
        messages: newMessages,
        createdAt: conv.createdAt,
        updatedAt: DateTime.now(),
      );
      // Sort by latest
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  Future<void> loadConversations() async {
    _loading = true;
    notifyListeners();
    final data = await _api.get('/conversations') as List<dynamic>;
    _conversations = data.map((c) => ConversationModel.fromJson(c as Map<String, dynamic>)).toList();
    _loading = false;
    notifyListeners();
  }

  Future<ConversationModel> startConversation(String userId) async {
    final data = await _api.post('/conversations', data: {'userId': userId});
    final conv = ConversationModel.fromJson(data as Map<String, dynamic>);
    final exists = _conversations.indexWhere((c) => c.id == conv.id);
    if (exists < 0) _conversations.insert(0, conv);
    notifyListeners();
    _socket.joinConversation(conv.id);
    return conv;
  }

  Future<void> loadMessages(String conversationId) async {
    final data = await _api.get('/conversations/$conversationId/messages') as List<dynamic>;
    _messages[conversationId] = data.map((m) => MessageModel.fromJson(m as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> loadGroupMessages(String groupId) async {
    final data = await _api.get('/groups/$groupId/messages') as List<dynamic>;
    _messages['group:$groupId'] = data.map((m) => MessageModel.fromJson(m as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> loadGroups() async {
    final data = await _api.get('/groups') as List<dynamic>;
    _groups = data.map((g) => GroupModel.fromJson(g as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<GroupModel> createGroup(String name, List<String> memberIds, {String? description}) async {
    final data = await _api.post('/groups', data: {'name': name, 'memberIds': memberIds, 'description': description});
    final group = GroupModel.fromJson(data as Map<String, dynamic>);
    _groups.insert(0, group);
    notifyListeners();
    return group;
  }

  void sendMessage(String conversationId, String content, {String type = 'TEXT', String? replyToId}) {
    _socket.sendMessage(
      conversationId: conversationId,
      content: content,
      type: type,
      replyToId: replyToId,
    );
  }

  void sendGroupMessage(String groupId, String content, {String type = 'TEXT', String? replyToId}) {
    _socket.sendGroupMessage(groupId: groupId, content: content, type: type, replyToId: replyToId);
  }
}
