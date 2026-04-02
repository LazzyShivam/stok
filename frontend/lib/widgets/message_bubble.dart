import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSenderName;
  final VoidCallback? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderName = false,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return _buildSystemMessage();
    }

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) const SizedBox(width: 4),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: _bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showSenderName && !isMe && message.sender != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.sender!.name,
                            style: TextStyle(
                              color: _senderColor(message.sender!.id),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (message.replyTo != null) _buildReplyPreview(),
                      if (message.type == MessageType.image) _buildImage()
                      else if (message.isVoice) _buildVoiceMessage()
                      else _buildTextContent(),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.type == MessageType.aiResponse)
                            const Icon(Icons.auto_awesome, size: 10, color: AppTheme.secondary),
                          if (message.type == MessageType.aiResponse)
                            const SizedBox(width: 3),
                          Text(
                            DateFormat('h:mm a').format(message.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white.withOpacity(0.6) : AppTheme.onSurfaceMuted,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Color get _bubbleColor {
    if (message.type == MessageType.aiResponse) return AppTheme.aiBubble;
    return isMe ? AppTheme.sentBubble : AppTheme.receivedBubble;
  }

  Widget _buildTextContent() {
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: isMe ? Colors.white60 : AppTheme.onSurfaceMuted,
          fontSize: 14,
        ),
      );
    }
    return Text(
      message.content ?? '',
      style: TextStyle(
        color: isMe ? Colors.white : AppTheme.onSurface,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildImage() {
    final url = message.mediaUrl != null
        ? (message.mediaUrl!.startsWith('http') ? message.mediaUrl! : '${AppConfig.uploadUrl}${message.mediaUrl}')
        : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: 200,
        height: 200,
        placeholder: (_, __) => Container(
          width: 200, height: 200,
          color: AppTheme.surfaceVariant,
          child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 200, height: 200,
          color: AppTheme.surfaceVariant,
          child: const Icon(Icons.broken_image, color: AppTheme.onSurfaceMuted),
        ),
      ),
    );
  }

  Widget _buildVoiceMessage() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_arrow_rounded, color: isMe ? Colors.white : AppTheme.primary, size: 28),
        const SizedBox(width: 6),
        Flexible(
          child: Container(
            height: 32,
            constraints: const BoxConstraints(maxWidth: 150),
            child: CustomPaint(
              painter: _WaveformPainter(color: isMe ? Colors.white54 : AppTheme.onSurfaceMuted),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.mic_rounded, size: 14, color: isMe ? Colors.white60 : AppTheme.onSurfaceMuted),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message.replyTo?.sender?.name ?? '', style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(message.replyTo?.content ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isMe ? Colors.white70 : AppTheme.onSurfaceMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.content ?? '', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () { Navigator.pop(context); onReply?.call(); },
            ),
            if (message.content != null)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content!));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Color _senderColor(String id) {
    final colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal];
    return colors[id.hashCode.abs() % colors.length];
  }
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2..strokeCap = StrokeCap.round;
    const bars = 20;
    final spacing = size.width / bars;
    final heights = [0.3, 0.6, 0.9, 0.5, 0.8, 0.4, 1.0, 0.6, 0.3, 0.7, 0.9, 0.5, 0.4, 0.8, 0.3, 0.6, 1.0, 0.7, 0.4, 0.5];
    for (int i = 0; i < bars; i++) {
      final h = size.height * heights[i % heights.length];
      final x = i * spacing + spacing / 2;
      final top = (size.height - h) / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
