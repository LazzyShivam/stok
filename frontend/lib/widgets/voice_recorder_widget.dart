import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final String conversationId;
  final bool isGroup;
  final VoidCallback onDismiss;

  const VoiceRecorderWidget({
    super.key,
    required this.conversationId,
    this.isGroup = false,
    required this.onDismiss,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSending = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _filePath;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulse = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      widget.onDismiss();
      return;
    }

    final dir = await getTemporaryDirectory();
    _filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _filePath!);

    setState(() => _isRecording = true);
    _pulseCtrl.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording) return;
    setState(() { _isRecording = false; _isSending = true; });
    _timer?.cancel();
    _pulseCtrl.stop();

    await _recorder.stop();

    if (_filePath != null && File(_filePath!).existsSync()) {
      final api = context.read<ApiService>();
      final formData = FormData.fromMap({
        'media': await MultipartFile.fromFile(_filePath!, filename: 'voice.m4a'),
        'type': 'VOICE',
      });

      if (widget.isGroup) {
        await api.postForm('/groups/${widget.conversationId}/messages', formData);
      } else {
        await api.postForm('/conversations/${widget.conversationId}/messages', formData);
      }
    }

    setState(() => _isSending = false);
    widget.onDismiss();
  }

  void _cancel() async {
    _timer?.cancel();
    _pulseCtrl.stop();
    await _recorder.stop();
    widget.onDismiss();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _cancel,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: AppTheme.error, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  if (_isRecording)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.mic_rounded, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomPaint(
                      size: const Size(double.infinity, 28),
                      painter: _LiveWaveformPainter(animate: _isRecording),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _isSending
                ? const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                : GestureDetector(
                    onTap: _stopAndSend,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  final bool animate;
  _LiveWaveformPainter({required this.animate});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = animate ? AppTheme.primary : AppTheme.onSurfaceMuted
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const bars = 24;
    final spacing = size.width / bars;
    for (int i = 0; i < bars; i++) {
      final rng = (i * 7 + 3) % 10;
      final h = animate ? size.height * (0.2 + rng * 0.08) : size.height * 0.3;
      final x = i * spacing + spacing / 2;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter old) => old.animate != animate;
}
