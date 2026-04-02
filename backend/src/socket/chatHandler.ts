import { Server, Socket } from 'socket.io';
import { GroupMember, Message } from '@prisma/client';
import prisma from '../config/database';
import { generateAgentResponse } from '../services/aiService';

export const registerChatHandlers = (io: Server, socket: Socket, userId: string): void => {

  // Join a specific conversation room
  socket.on('join_conversation', async (conversationId: string) => {
    const member = await prisma.conversationMember.findFirst({ where: { conversationId, userId } });
    if (member) socket.join(`conv:${conversationId}`);
  });

  // Leave conversation room
  socket.on('leave_conversation', (conversationId: string) => {
    socket.leave(`conv:${conversationId}`);
  });

  // Typing indicator
  socket.on('typing_start', ({ conversationId }: { conversationId: string }) => {
    socket.to(`conv:${conversationId}`).emit('user_typing', { userId, conversationId });
  });

  socket.on('typing_stop', ({ conversationId }: { conversationId: string }) => {
    socket.to(`conv:${conversationId}`).emit('user_stopped_typing', { userId, conversationId });
  });

  // Group typing
  socket.on('group_typing_start', ({ groupId }: { groupId: string }) => {
    socket.to(`group:${groupId}`).emit('group_user_typing', { userId, groupId });
  });

  socket.on('group_typing_stop', ({ groupId }: { groupId: string }) => {
    socket.to(`group:${groupId}`).emit('group_user_stopped_typing', { userId, groupId });
  });

  // Mark messages as read
  socket.on('mark_read', async ({ conversationId }: { conversationId: string }) => {
    await prisma.conversationMember.updateMany({
      where: { conversationId, userId },
      data: { lastReadAt: new Date() },
    });
    socket.to(`conv:${conversationId}`).emit('messages_read', { userId, conversationId });
  });

  // Send message via socket (alternative to REST for real-time)
  socket.on('send_message', async ({ conversationId, content, type = 'TEXT', replyToId, metadata }: {
    conversationId: string;
    content: string;
    type?: string;
    replyToId?: string;
    metadata?: any;
  }) => {
    const member = await prisma.conversationMember.findFirst({ where: { conversationId, userId } });
    if (!member) return;

    const message = await prisma.message.create({
      data: {
        conversationId,
        senderId: userId,
        content,
        type: type as any,
        replyToId: replyToId || null,
        metadata: metadata || null,
      },
      include: {
        sender: { select: { id: true, name: true, avatar: true, isAgent: true } },
        replyTo: { include: { sender: { select: { id: true, name: true } } } },
      },
    });

    await prisma.conversation.update({ where: { id: conversationId }, data: { updatedAt: new Date() } });
    io.to(`conv:${conversationId}`).emit('new_message', message);

    // Check if the conversation has an AI agent and auto-respond
    const conv = await prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { members: { include: { user: true } } },
    });

    const agentMember = (conv as any)?.members?.find((m: any) => m.user?.isAgent);
    if (agentMember?.user && agentMember.userId !== userId) {
      const agent = agentMember.user;
      const config = agent.agentConfig as any;
      if (!config) return;

      // Get recent conversation history
      const history = await prisma.message.findMany({
        where: { conversationId, isDeleted: false, senderId: { not: agent.id } },
        orderBy: { createdAt: 'desc' },
        take: 20,
        include: { sender: true },
      });

      const chatHistory = history.reverse().map((m: Message) => ({
        role: m.senderId === userId ? 'user' as const : 'assistant' as const,
        content: m.content || '',
      }));

      try {
        // Emit typing indicator
        io.to(`conv:${conversationId}`).emit('user_typing', { userId: agent.id, conversationId });

        const response = await generateAgentResponse(
          { model: config.model || 'claude-sonnet-4-6', systemPrompt: config.systemPrompt, name: agent.name },
          chatHistory,
          content
        );

        const agentMessage = await prisma.message.create({
          data: {
            conversationId,
            senderId: agent.id,
            content: response,
            type: 'AI_RESPONSE',
          },
          include: { sender: { select: { id: true, name: true, avatar: true, isAgent: true } } },
        });

        io.to(`conv:${conversationId}`).emit('user_stopped_typing', { userId: agent.id, conversationId });
        io.to(`conv:${conversationId}`).emit('new_message', agentMessage);
      } catch (err) {
        io.to(`conv:${conversationId}`).emit('user_stopped_typing', { userId: agent.id, conversationId });
        console.error('[Socket] AI response error:', err);
      }
    }
  });

  // Send group message via socket
  socket.on('send_group_message', async ({ groupId, content, type = 'TEXT', replyToId }: {
    groupId: string;
    content: string;
    type?: string;
    replyToId?: string;
  }) => {
    const member = await prisma.groupMember.findFirst({ where: { groupId, userId } });
    if (!member) return;

    // Get or create group conversation
    let conv = await prisma.conversation.findFirst({
      where: { messages: { some: { metadata: { path: ['groupId'], equals: groupId } } } },
    });
    if (!conv) {
      const group = await prisma.group.findUnique({ where: { id: groupId }, include: { members: true } });
      conv = await prisma.conversation.create({
        data: { members: { create: group!.members.map((m: GroupMember) => ({ userId: m.userId })) } },
      });
    }

    const message = await prisma.message.create({
      data: {
        conversationId: conv.id,
        senderId: userId,
        content,
        type: type as any,
        replyToId: replyToId || null,
        metadata: { groupId },
      },
      include: {
        sender: { select: { id: true, name: true, avatar: true, isAgent: true } },
        replyTo: { include: { sender: { select: { id: true, name: true } } } },
      },
    });

    io.to(`group:${groupId}`).emit('new_group_message', { groupId, message });
  });
};
