import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/voice_recorder_widget.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showVoiceRecorder = false;
  String? _replyToId;

  @override
  void initState() {
    super.initState();
    context.read<ChatProvider>().loadGroupMessages(widget.groupId);
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatProvider>().sendGroupMessage(widget.groupId, text, replyToId: _replyToId);
    setState(() => _replyToId = null);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(widget.groupName[0].toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(widget.groupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.group_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, chat, __) {
                final messages = chat.messagesFor('group:${widget.groupId}');
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    return MessageBubble(
                      message: msg,
                      isMe: msg.senderId == myId,
                      showSenderName: true,
                      onReply: () => setState(() => _replyToId = msg.id),
                    );
                  },
                );
              },
            ),
          ),
          if (_showVoiceRecorder)
            VoiceRecorderWidget(
              conversationId: widget.groupId,
              isGroup: true,
              onDismiss: () => setState(() => _showVoiceRecorder = false),
            )
          else
            _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Message group...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, __) => GestureDetector(
                onTap: value.text.isNotEmpty ? _sendMessage : () => setState(() => _showVoiceRecorder = true),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: value.text.isNotEmpty ? AppTheme.primary : AppTheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    value.text.isNotEmpty ? Icons.send_rounded : Icons.mic_rounded,
                    color: value.text.isNotEmpty ? Colors.white : AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
