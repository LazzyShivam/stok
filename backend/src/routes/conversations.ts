import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { authenticate, AuthRequest } from '../middleware/auth';
import prisma from '../config/database';
import { getIO } from '../socket';

const router = Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const type = file.mimetype.startsWith('image') ? 'images' : file.mimetype.startsWith('video') ? 'videos' : file.mimetype.startsWith('audio') ? 'audio' : 'files';
    cb(null, `./uploads/${type}`);
  },
  filename: (_req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`),
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

// GET /api/conversations - list user's conversations
router.get('/', authenticate, async (req: AuthRequest, res: Response) => {
  const conversations = await prisma.conversation.findMany({
    where: { members: { some: { userId: req.userId } } },
    include: {
      members: { include: { user: { select: { id: true, name: true, avatar: true, status: true, phone: true } } } },
      messages: { orderBy: { createdAt: 'desc' }, take: 1 },
    },
    orderBy: { updatedAt: 'desc' },
  });
  res.json(conversations);
});

// POST /api/conversations - start or get direct conversation
router.post('/', authenticate,
  body('userId').isUUID(),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { userId } = req.body;
    if (userId === req.userId) return res.status(400).json({ error: 'Cannot chat with yourself' });

    // Find existing conversation between exactly these two users
    const existing = await prisma.conversation.findFirst({
      where: {
        type: 'DIRECT',
        AND: [
          { members: { some: { userId: req.userId! } } },
          { members: { some: { userId } } },
        ],
      },
      include: {
        members: { include: { user: { select: { id: true, name: true, avatar: true, status: true, phone: true } } } },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });

    if (existing) return res.json(existing);

    const conv = await prisma.conversation.create({
      data: {
        type: 'DIRECT',
        members: { create: [{ userId: req.userId! }, { userId }] },
      },
      include: {
        members: { include: { user: { select: { id: true, name: true, avatar: true, status: true, phone: true } } } },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });
    res.status(201).json(conv);
  }
);

// GET /api/conversations/:id/messages
router.get('/:id/messages', authenticate, async (req: AuthRequest, res: Response) => {
  const isMember = await prisma.conversationMember.findFirst({
    where: { conversationId: req.params.id, userId: req.userId },
  });
  if (!isMember) return res.status(403).json({ error: 'Access denied' });

  const { cursor, limit = '50' } = req.query;
  const take = Math.min(parseInt(limit as string, 10), 100);

  const messages = await prisma.message.findMany({
    where: { conversationId: req.params.id, isDeleted: false },
    include: {
      sender: { select: { id: true, name: true, avatar: true, isAgent: true } },
      replyTo: { include: { sender: { select: { id: true, name: true } } } },
    },
    orderBy: { createdAt: 'desc' },
    take,
    ...(cursor ? { cursor: { id: cursor as string }, skip: 1 } : {}),
  });

  // Update last read
  await prisma.conversationMember.update({
    where: { conversationId_userId: { conversationId: req.params.id, userId: req.userId! } },
    data: { lastReadAt: new Date() },
  });

  res.json(messages.reverse());
});

// POST /api/conversations/:id/messages
router.post('/:id/messages', authenticate, upload.single('media'),
  async (req: AuthRequest, res: Response) => {
    const isMember = await prisma.conversationMember.findFirst({
      where: { conversationId: req.params.id, userId: req.userId },
    });
    if (!isMember) return res.status(403).json({ error: 'Access denied' });

    const { content, type = 'TEXT', replyToId, metadata } = req.body;
    let mediaUrl: string | undefined;

    if (req.file) {
      const subdir = req.file.mimetype.startsWith('image') ? 'images' : req.file.mimetype.startsWith('video') ? 'videos' : req.file.mimetype.startsWith('audio') ? 'audio' : 'files';
      mediaUrl = `/uploads/${subdir}/${req.file.filename}`;
    }

    const message = await prisma.message.create({
      data: {
        conversationId: req.params.id,
        senderId: req.userId!,
        content,
        type: type as any,
        mediaUrl,
        replyToId: replyToId || null,
        metadata: metadata ? JSON.parse(metadata) : null,
      },
      include: {
        sender: { select: { id: true, name: true, avatar: true, isAgent: true } },
        replyTo: { include: { sender: { select: { id: true, name: true } } } },
      },
    });

    await prisma.conversation.update({ where: { id: req.params.id }, data: { updatedAt: new Date() } });

    // Emit to socket room
    getIO().to(`conv:${req.params.id}`).emit('new_message', message);

    res.status(201).json(message);
  }
);

// DELETE /api/conversations/:convId/messages/:msgId
router.delete('/:convId/messages/:msgId', authenticate, async (req: AuthRequest, res: Response) => {
  const message = await prisma.message.findFirst({
    where: { id: req.params.msgId, conversationId: req.params.convId, senderId: req.userId },
  });
  if (!message) return res.status(404).json({ error: 'Message not found' });

  await prisma.message.update({ where: { id: message.id }, data: { isDeleted: true, content: null } });
  getIO().to(`conv:${req.params.convId}`).emit('message_deleted', { messageId: message.id });
  res.json({ message: 'Deleted' });
});

export default router;
