import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/call_provider.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/voice_recorder_widget.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/ai_prompt_widget.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  final String? avatarUrl;
  final String? userId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.avatarUrl,
    this.userId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  bool _showVoiceRecorder = false;
  bool _showAiPrompt = false;
  Timer? _typingTimer;
  String? _replyToId;
  MessageModel? _replyToMessage;
  UserModel? _remoteUser;
  bool _isRemoteAgent = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await context.read<ChatProvider>().loadMessages(widget.conversationId);
    if (widget.userId != null) {
      final api = context.read<ApiService>();
      final userData = await api.get('/users/${widget.userId}');
      setState(() {
        _remoteUser = UserModel.fromJson(userData as Map<String, dynamic>);
        _isRemoteAgent = _remoteUser?.isAgent ?? false;
      });
    }
    _scrollToBottom();
    if (widget.userId != null) {
      context.read<PresenceProvider>().checkPresence([widget.userId!]);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _onTextChanged(String text) {
    final chat = context.read<ChatProvider>();
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      chat.messagesFor(widget.conversationId); // trigger
      context.read<ChatProvider>(); // just to access socket via provider
      // Send typing via socket
      context.read<ChatProvider>();
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    context.read<ChatProvider>().sendMessage(
      widget.conversationId,
      text,
      replyToId: _replyToId,
    );

    setState(() {
      _replyToId = null;
      _replyToMessage = null;
    });
    _scrollToBottom();
  }

  void _initiateCall(bool isVideo) async {
    if (_remoteUser == null) return;
    final api = context.read<ApiService>();
    final result = await api.post('/calls/initiate', data: {
      'targetUserId': _remoteUser!.id,
      'type': isVideo ? 'VIDEO' : 'VOICE',
    });
    if (!mounted) return;
    Navigator.pushNamed(context, '/video-call', arguments: {
      'callId': result['callId'],
      'remoteUserId': _remoteUser!.id,
      'remoteUserName': widget.title,
      'isVideo': isVideo,
      'isIncoming': false,
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
            UserAvatar(
              userId: widget.userId ?? '',
              avatarUrl: widget.avatarUrl,
              name: widget.title,
              size: 38,
              showStatus: true,
              status: widget.userId != null
                  ? context.watch<PresenceProvider>().statusOf(widget.userId!)
                  : UserStatus.offline,
              isAgent: _isRemoteAgent,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (widget.userId != null)
                  Consumer<PresenceProvider>(
                    builder: (_, presence, __) {
                      final status = presence.statusOf(widget.userId!);
                      return Text(
                        status == UserStatus.online ? 'Online' : _isRemoteAgent ? 'AI Agent' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: status == UserStatus.online ? AppTheme.onlineColor : AppTheme.onSurfaceMuted,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (!_isRemoteAgent) ...[
            IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => _initiateCall(false)),
            IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () => _initiateCall(true)),
          ],
          if (_isRemoteAgent)
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () => setState(() => _showAiPrompt = !_showAiPrompt),
              tooltip: 'AI Prompts',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_showAiPrompt)
            AiPromptWidget(
              onPromptSelected: (p) {
                _controller.text = p;
                setState(() => _showAiPrompt = false);
              },
            ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, chat, __) {
                final messages = chat.messagesFor(widget.conversationId);
                final typing = chat.typingUsersFor(widget.conversationId)
                    .where((id) => id != myId)
                    .isNotEmpty;

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length + (typing ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (typing && i == messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = messages[i];
                      final isMe = msg.senderId == myId;
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                        onReply: () => setState(() {
                          _replyToId = msg.id;
                          _replyToMessage = msg;
                        }),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (_replyToMessage != null) _buildReplyPreview(),
          if (_showVoiceRecorder)
            VoiceRecorderWidget(
              conversationId: widget.conversationId,
              onDismiss: () => setState(() => _showVoiceRecorder = false),
            )
          else
            _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
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
                onChanged: _onTextChanged,
                maxLines: 5,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Message...',
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
              builder: (_, value, __) {
                if (value.text.isNotEmpty) {
                  return GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => setState(() => _showVoiceRecorder = true),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, color: AppTheme.primary, size: 22),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyToMessage?.sender?.name ?? 'Unknown',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  _replyToMessage?.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() { _replyToId = null; _replyToMessage = null; }),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _BouncingDot(delay: Duration(milliseconds: i * 150)),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDot extends StatefulWidget {
  final Duration delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: AppTheme.onSurfaceMuted, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
