import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../services/webrtc_service.dart';
import '../../theme/app_theme.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String remoteUserId;
  final String remoteUserName;
  final bool isVideo;
  final bool isIncoming;
  final Map<String, dynamic>? offer;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.remoteUserId,
    required this.remoteUserName,
    required this.isVideo,
    this.isIncoming = false,
    this.offer,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  late WebRTCService _webrtc;
  bool _callConnected = false;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _setupCall();
  }

  Future<void> _setupCall() async {
    _webrtc = context.read<WebRTCService>();

    _webrtc.onLocalStream = (stream) {
      setState(() => _localRenderer.srcObject = stream);
    };

    _webrtc.onRemoteStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        _callConnected = true;
        _startTimer();
      });
    };

    _webrtc.onCallStateChanged = (state) {
      if (state == CallState.ended && mounted) {
        Navigator.pop(context);
      }
    };

    _webrtc.onHangup = () {
      if (mounted) Navigator.pop(context);
    };

    if (widget.isIncoming && widget.offer != null) {
      await _webrtc.answerCall(
        callId: widget.callId,
        callerId: widget.remoteUserId,
        offer: widget.offer!,
        isVideo: widget.isVideo,
      );
    } else {
      await _webrtc.startCall(
        callId: widget.callId,
        targetUserId: widget.remoteUserId,
        isVideo: widget.isVideo,
      );
    }
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (widget.isVideo && _callConnected)
            Positioned.fill(
              child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            )
          else
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1A1A2E),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppTheme.primary.withOpacity(0.2),
                      child: Text(
                        widget.remoteUserName.isNotEmpty ? widget.remoteUserName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(widget.remoteUserName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                      _callConnected ? _formatDuration(_callDuration) : 'Connecting...',
                      style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),

          // Local video (PiP)
          if (widget.isVideo)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              right: 16,
              child: GestureDetector(
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black,
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(_localRenderer, mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (_callConnected && widget.isVideo) ...[
                    Text(widget.remoteUserName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(_formatDuration(_callDuration),
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 40, right: 40, top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    color: _isMuted ? Colors.grey : Colors.white,
                    onTap: () { _webrtc.toggleMute(); setState(() => _isMuted = !_isMuted); },
                  ),
                  if (widget.isVideo)
                    _controlButton(
                      icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      label: _isCameraOff ? 'Camera Off' : 'Camera',
                      color: _isCameraOff ? Colors.grey : Colors.white,
                      onTap: () { _webrtc.toggleCamera(); setState(() => _isCameraOff = !_isCameraOff); },
                    ),
                  _controlButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    color: Colors.white,
                    backgroundColor: AppTheme.error,
                    size: 64,
                    onTap: () { _webrtc.endCall(); Navigator.pop(context); },
                  ),
                  if (widget.isVideo)
                    _controlButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Flip',
                      color: Colors.white,
                      onTap: () => _webrtc.switchCamera(),
                    ),
                  _controlButton(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    label: 'Speaker',
                    color: _isSpeakerOn ? Colors.white : Colors.grey,
                    onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? backgroundColor,
    double size = 52,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
