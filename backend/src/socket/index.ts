import { Server as HTTPServer } from 'http';
import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { ChannelMember, ConversationMember, GroupMember } from '@prisma/client';
import prisma from '../config/database';
import { registerChatHandlers } from './chatHandler';
import { registerPresenceHandlers } from './presenceHandler';
import { registerVideoHandlers } from './videoHandler';

let io: Server;

export const initializeSocket = (server: HTTPServer): void => {
  io = new Server(server, {
    cors: {
      origin: process.env.FRONTEND_URL || '*',
      methods: ['GET', 'POST'],
      credentials: true,
    },
    transports: ['websocket', 'polling'],
    pingTimeout: 30000,
    pingInterval: 10000,
  });

  // JWT Authentication middleware
  io.use(async (socket: Socket, next) => {
    const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
    if (!token) return next(new Error('Authentication required'));

    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET || 'secret') as { userId: string };
      const user = await prisma.user.findUnique({
        where: { id: payload.userId },
        select: { id: true, name: true, avatar: true, isAgent: true },
      });
      if (!user) return next(new Error('User not found'));
      (socket as any).userId = user.id;
      (socket as any).user = user;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', async (socket: Socket) => {
    const userId = (socket as any).userId as string;
    console.log(`[Socket] User connected: ${userId} (${socket.id})`);

    // Join personal room
    socket.join(`user:${userId}`);

    // Join conversation rooms the user is part of
    const memberships = await prisma.conversationMember.findMany({ where: { userId } });
    memberships.forEach((m: ConversationMember) => socket.join(`conv:${m.conversationId}`));

    // Join group rooms
    const groups = await prisma.groupMember.findMany({ where: { userId } });
    groups.forEach((g: GroupMember) => socket.join(`group:${g.groupId}`));

    // Join channel rooms
    const channels = await prisma.channelMember.findMany({ where: { userId } });
    channels.forEach((c: ChannelMember) => socket.join(`channel:${c.channelId}`));

    // Register event handlers
    registerChatHandlers(io, socket, userId);
    registerPresenceHandlers(io, socket, userId);
    registerVideoHandlers(io, socket, userId);

    // Mark user online
    await prisma.user.update({ where: { id: userId }, data: { status: 'ONLINE', lastSeen: new Date() } });
    io.emit('user_status', { userId, status: 'ONLINE' });

    socket.on('disconnect', async () => {
      console.log(`[Socket] User disconnected: ${userId}`);
      await prisma.user.update({ where: { id: userId }, data: { status: 'OFFLINE', lastSeen: new Date() } });
      io.emit('user_status', { userId, status: 'OFFLINE', lastSeen: new Date() });
    });
  });

  console.log('[Socket] Socket.io initialized');
};

export const getIO = (): Server => {
  if (!io) throw new Error('Socket.io not initialized');
  return io;
};
