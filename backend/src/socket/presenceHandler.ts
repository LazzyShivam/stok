import { Server, Socket } from 'socket.io';
import prisma from '../config/database';

export const registerPresenceHandlers = (io: Server, socket: Socket, userId: string): void => {

  // Manual status update (AWAY, etc.)
  socket.on('update_status', async ({ status }: { status: 'ONLINE' | 'AWAY' | 'OFFLINE' }) => {
    await prisma.user.update({ where: { id: userId }, data: { status } });
    io.emit('user_status', { userId, status });
  });

  // Request online status of a list of users
  socket.on('check_presence', async ({ userIds }: { userIds: string[] }) => {
    const users = await prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, status: true, lastSeen: true },
    });
    socket.emit('presence_list', users);
  });
};
