import { Server, Socket } from 'socket.io';

// WebRTC signaling for peer-to-peer video/voice calls
export const registerVideoHandlers = (_io: Server, socket: Socket, userId: string): void => {

  // Forward WebRTC offer to target
  socket.on('webrtc_offer', ({ targetUserId, callId, offer }: { targetUserId: string; callId: string; offer: Record<string, unknown> }) => {
    socket.to(`user:${targetUserId}`).emit('webrtc_offer', { callId, offer, fromUserId: userId });
  });

  // Forward WebRTC answer
  socket.on('webrtc_answer', ({ targetUserId, callId, answer }: { targetUserId: string; callId: string; answer: Record<string, unknown> }) => {
    socket.to(`user:${targetUserId}`).emit('webrtc_answer', { callId, answer, fromUserId: userId });
  });

  // Forward ICE candidates
  socket.on('ice_candidate', ({ targetUserId, callId, candidate }: { targetUserId: string; callId: string; candidate: Record<string, unknown> }) => {
    socket.to(`user:${targetUserId}`).emit('ice_candidate', { callId, candidate, fromUserId: userId });
  });

  // Call hangup
  socket.on('call_hangup', ({ targetUserId, callId }: { targetUserId: string; callId: string }) => {
    socket.to(`user:${targetUserId}`).emit('call_hangup', { callId, fromUserId: userId });
  });

  // Call reject
  socket.on('call_reject', ({ targetUserId, callId }: { targetUserId: string; callId: string }) => {
    socket.to(`user:${targetUserId}`).emit('call_rejected', { callId, fromUserId: userId });
  });

  // Toggle audio/video state
  socket.on('media_toggle', ({ targetUserId, callId, type, enabled }: { targetUserId: string; callId: string; type: 'audio' | 'video'; enabled: boolean }) => {
    socket.to(`user:${targetUserId}`).emit('remote_media_toggle', { callId, userId, type, enabled });
  });
};
