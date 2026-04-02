import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_config.dart';
import 'socket_service.dart';

enum CallState { idle, calling, ringing, active, ended }

class WebRTCService {
  final SocketService _socket;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? _callId;
  String? _targetUserId;
  bool _isVideo = true;
  bool _isMuted = false;
  bool _isCameraOff = false;

  void Function(MediaStream)? onLocalStream;
  void Function(MediaStream)? onRemoteStream;
  void Function(CallState)? onCallStateChanged;
  void Function()? onHangup;

  WebRTCService(this._socket) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socket.on('webrtc_offer', (data) async {
      if (data is Map) {
        await _handleOffer(
          data['callId'] as String,
          data['fromUserId'] as String,
          data['offer'] as Map<String, dynamic>,
        );
      }
    });

    _socket.on('webrtc_answer', (data) async {
      if (data is Map) {
        await _handleAnswer(data['answer'] as Map<String, dynamic>);
      }
    });

    _socket.on('ice_candidate', (data) async {
      if (data is Map) {
        await _handleIceCandidate(data['candidate'] as Map<String, dynamic>);
      }
    });

    _socket.on('call_hangup', (_) => endCall());

    _socket.on('call_rejected', (_) {
      onCallStateChanged?.call(CallState.ended);
      _cleanup();
    });
  }

  Future<void> startCall({
    required String callId,
    required String targetUserId,
    required bool isVideo,
  }) async {
    _callId = callId;
    _targetUserId = targetUserId;
    _isVideo = isVideo;

    await _createPeerConnection();
    await _getUserMedia();
    await _createOffer();
    onCallStateChanged?.call(CallState.calling);
  }

  Future<void> answerCall({
    required String callId,
    required String callerId,
    required Map<String, dynamic> offer,
    required bool isVideo,
  }) async {
    _callId = callId;
    _targetUserId = callerId;
    _isVideo = isVideo;

    await _createPeerConnection();
    await _getUserMedia();

    final sdp = RTCSessionDescription(offer['sdp'] as String, offer['type'] as String);
    await _peerConnection!.setRemoteDescription(sdp);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket.sendAnswer(callerId, callId, {'sdp': answer.sdp, 'type': answer.type});
    onCallStateChanged?.call(CallState.active);
  }

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': AppConfig.iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      if (_targetUserId != null && _callId != null) {
        _socket.sendIceCandidate(_targetUserId!, _callId!, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallStateChanged?.call(CallState.active);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall();
      }
    };
  }

  Future<void> _getUserMedia() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _isVideo ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      } : false,
    });

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    onLocalStream?.call(_localStream!);
  }

  Future<void> _createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _isVideo,
    });
    await _peerConnection!.setLocalDescription(offer);
    _socket.sendOffer(_targetUserId!, _callId!, {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _handleOffer(String callId, String fromUserId, Map<String, dynamic> offer) async {
    // This is handled externally via incoming_call event, then answerCall() is called
    _callId = callId;
    _targetUserId = fromUserId;
  }

  Future<void> _handleAnswer(Map<String, dynamic> answer) async {
    final sdp = RTCSessionDescription(answer['sdp'] as String, answer['type'] as String);
    await _peerConnection?.setRemoteDescription(sdp);
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> candidateData) async {
    final candidate = RTCIceCandidate(
      candidateData['candidate'] as String,
      candidateData['sdpMid'] as String?,
      candidateData['sdpMLineIndex'] as int?,
    );
    await _peerConnection?.addCandidate(candidate);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    if (_targetUserId != null && _callId != null) {
      _socket.emit('media_toggle', {
        'targetUserId': _targetUserId,
        'callId': _callId,
        'type': 'audio',
        'enabled': !_isMuted,
      });
    }
  }

  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isCameraOff;
    });
  }

  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) await Helper.switchCamera(videoTrack);
  }

  void endCall() {
    if (_targetUserId != null && _callId != null) {
      _socket.hangup(_targetUserId!, _callId!);
    }
    _cleanup();
    onCallStateChanged?.call(CallState.ended);
    onHangup?.call();
  }

  void _cleanup() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _callId = null;
    _targetUserId = null;
  }

  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isVideo => _isVideo;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}
