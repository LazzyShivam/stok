import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';

enum CallState { idle, calling, ringing, active, ended }

class IncomingCallData {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;

  const IncomingCallData({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.isVideo,
  });
}

class CallProvider extends ChangeNotifier {
  final SocketService _socket;
  final WebRTCService _webrtc;

  CallState _state = CallState.idle;
  IncomingCallData? _incomingCall;
  UserModel? _remoteUser;
  String? _activeCallId;
  bool _isVideo = false;

  CallProvider(this._socket, this._webrtc) {
    _socket.on('incoming_call', (data) {
      if (data is Map) {
        _incomingCall = IncomingCallData(
          callId: data['callId'] as String,
          callerId: data['callerId'] as String,
          callerName: data['callerName'] as String? ?? 'Unknown',
          callerAvatar: data['callerAvatar'] as String?,
          isVideo: (data['callType'] as String?) == 'VIDEO',
        );
        _state = CallState.ringing;
        notifyListeners();
      }
    });

    _webrtc.onCallStateChanged = (state) {
      switch (state) {
        case webrtc_CallState.active:
          _state = CallState.active;
        case webrtc_CallState.ended:
          _state = CallState.ended;
          Future.delayed(const Duration(seconds: 1), () {
            _state = CallState.idle;
            _incomingCall = null;
            _activeCallId = null;
            notifyListeners();
          });
        default:
          break;
      }
      notifyListeners();
    };
  }

  CallState get state => _state;
  IncomingCallData? get incomingCall => _incomingCall;
  UserModel? get remoteUser => _remoteUser;
  bool get isVideo => _isVideo;
  String? get activeCallId => _activeCallId;
  bool get hasIncomingCall => _incomingCall != null && _state == CallState.ringing;

  Future<void> initiateCall(String callId, UserModel target, bool isVideo) async {
    _remoteUser = target;
    _isVideo = isVideo;
    _activeCallId = callId;
    _state = CallState.calling;
    notifyListeners();

    await _webrtc.startCall(
      callId: callId,
      targetUserId: target.id,
      isVideo: isVideo,
    );
  }

  Future<void> acceptCall() async {
    final call = _incomingCall;
    if (call == null) return;
    _activeCallId = call.callId;
    _state = CallState.active;
    notifyListeners();
  }

  void rejectCall() {
    final call = _incomingCall;
    if (call == null) return;
    _socket.rejectCall(call.callerId, call.callId);
    _incomingCall = null;
    _state = CallState.idle;
    notifyListeners();
  }

  void endCall() {
    _webrtc.endCall();
    _state = CallState.idle;
    _incomingCall = null;
    _activeCallId = null;
    notifyListeners();
  }

  void toggleMute() {
    _webrtc.toggleMute();
    notifyListeners();
  }

  void toggleCamera() {
    _webrtc.toggleCamera();
    notifyListeners();
  }

  bool get isMuted => _webrtc.isMuted;
  bool get isCameraOff => _webrtc.isCameraOff;
}

// Alias to avoid import conflict
typedef webrtc_CallState = CallState;
