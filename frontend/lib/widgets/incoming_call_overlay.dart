import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../theme/app_theme.dart';

class IncomingCallOverlay extends StatelessWidget {
  final IncomingCallData callData;

  const IncomingCallOverlay({super.key, required this.callData});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withOpacity(0.2),
                child: Text(
                  callData.callerName.isNotEmpty ? callData.callerName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(callData.callerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Row(
                      children: [
                        Icon(callData.isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                            size: 14, color: AppTheme.onSurfaceMuted),
                        const SizedBox(width: 4),
                        Text(callData.isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                            style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.read<CallProvider>().rejectCall(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      context.read<CallProvider>().acceptCall();
                      Navigator.pushNamed(context, '/video-call', arguments: {
                        'callId': callData.callId,
                        'remoteUserId': callData.callerId,
                        'remoteUserName': callData.callerName,
                        'isVideo': callData.isVideo,
                        'isIncoming': true,
                      });
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                      child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
