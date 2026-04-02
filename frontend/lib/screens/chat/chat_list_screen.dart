import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/presence_provider.dart';
import '../../models/conversation_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.pushNamed(context, '/user-search'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: () => Navigator.pushNamed(context, '/user-search'),
            tooltip: 'New Chat',
          ),
        ],
      ),
      body: Consumer2<ChatProvider, AuthProvider>(
        builder: (_, chat, auth, __) {
          if (chat.loading && chat.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final myId = auth.currentUser?.id ?? '';
          final filtered = chat.conversations.where((c) {
            if (_searchQuery.isEmpty) return true;
            final other = c.getOtherUser(myId);
            return other?.name.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search messages...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => chat.loadConversations(),
                        color: AppTheme.primary,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildConversationTile(filtered[i], myId),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/user-search'),
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conv, String myId) {
    final other = conv.getOtherUser(myId);
    if (other == null) return const SizedBox.shrink();

    final lastMsg = conv.lastMessage;
    final presence = context.read<PresenceProvider>();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        userId: other.id,
        avatarUrl: other.avatar,
        name: other.name,
        size: 52,
        showStatus: true,
        status: presence.statusOf(other.id),
        isAgent: other.isAgent,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              other.name.isEmpty ? other.phone : other.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          if (lastMsg != null)
            Text(
              timeago.format(lastMsg.createdAt, allowFromNow: true),
              style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted),
            ),
        ],
      ),
      subtitle: lastMsg == null
          ? const Text('No messages yet', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13))
          : Text(
              _getMessagePreview(lastMsg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
            ),
      onTap: () => Navigator.pushNamed(context, '/chat', arguments: {
        'conversationId': conv.id,
        'title': other.name.isEmpty ? other.phone : other.name,
        'avatarUrl': other.avatar,
        'userId': other.id,
      }),
    );
  }

  String _getMessagePreview(dynamic msg) {
    if (msg.isDeleted == true) return 'Message deleted';
    switch (msg.type.toString()) {
      case 'MessageType.image': return '📷 Photo';
      case 'MessageType.voice': return '🎤 Voice message';
      case 'MessageType.audio': return '🎵 Audio';
      case 'MessageType.video': return '🎥 Video';
      case 'MessageType.file': return '📎 File';
      case 'MessageType.eventCard': return '📅 Event';
      default: return msg.content ?? '';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 72, color: AppTheme.onSurfaceMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('No conversations yet', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Search for someone to start chatting', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
