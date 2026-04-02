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
  destination: './uploads/channels',
  filename: (_req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`),
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

// GET /api/channels - list public channels + joined channels
router.get('/', authenticate, async (req: AuthRequest, res: Response) => {
  const channels = await prisma.channel.findMany({
    where: {
      OR: [
        { isPublic: true },
        { members: { some: { userId: req.userId } } },
      ],
    },
    include: {
      _count: { select: { members: true, broadcasts: true } },
      members: { where: { userId: req.userId }, take: 1 },
    },
    orderBy: { createdAt: 'desc' },
  });
  res.json(channels.map((ch: typeof channels[number]) => ({ ...ch, isJoined: ch.members.length > 0 })));
});

// POST /api/channels - create channel
router.post('/', authenticate,
  body('name').isString().isLength({ min: 1, max: 100 }),
  body('description').optional().isString().isLength({ max: 500 }),
  body('isPublic').optional().isBoolean(),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { name, description, isPublic = true } = req.body;
    const channel = await prisma.channel.create({
      data: {
        name,
        description,
        isPublic,
        creatorId: req.userId!,
        members: { create: { userId: req.userId!, isAdmin: true } },
      },
      include: { _count: { select: { members: true } } },
    });
    res.status(201).json(channel);
  }
);

// GET /api/channels/:id
router.get('/:id', authenticate, async (req: AuthRequest, res: Response) => {
  const channel = await prisma.channel.findUnique({
    where: { id: req.params.id },
    include: {
      members: { include: { user: { select: { id: true, name: true, avatar: true, status: true } } } },
      _count: { select: { members: true, broadcasts: true } },
    },
  });
  if (!channel) return res.status(404).json({ error: 'Channel not found' });
  res.json(channel);
});

// POST /api/channels/:id/join
router.post('/:id/join', authenticate, async (req: AuthRequest, res: Response) => {
  const channel = await prisma.channel.findUnique({ where: { id: req.params.id } });
  if (!channel) return res.status(404).json({ error: 'Channel not found' });
  if (!channel.isPublic) return res.status(403).json({ error: 'Channel is private' });

  await prisma.channelMember.upsert({
    where: { channelId_userId: { channelId: req.params.id, userId: req.userId! } },
    create: { channelId: req.params.id, userId: req.userId! },
    update: {},
  });
  res.json({ message: 'Joined channel' });
});

// DELETE /api/channels/:id/leave
router.delete('/:id/leave', authenticate, async (req: AuthRequest, res: Response) => {
  await prisma.channelMember.deleteMany({
    where: { channelId: req.params.id, userId: req.userId },
  });
  res.json({ message: 'Left channel' });
});

// GET /api/channels/:id/broadcasts
router.get('/:id/broadcasts', authenticate, async (req: AuthRequest, res: Response) => {
  const { cursor, limit = '50' } = req.query;
  const take = Math.min(parseInt(limit as string, 10), 100);

  const broadcasts = await prisma.broadcast.findMany({
    where: { channelId: req.params.id },
    include: { sender: { select: { id: true, name: true, avatar: true } } },
    orderBy: { createdAt: 'desc' },
    take,
    ...(cursor ? { cursor: { id: cursor as string }, skip: 1 } : {}),
  });
  res.json(broadcasts.reverse());
});

// POST /api/channels/:id/broadcast
router.post('/:id/broadcast', authenticate, upload.single('media'), async (req: AuthRequest, res: Response) => {
  const admin = await prisma.channelMember.findFirst({
    where: { channelId: req.params.id, userId: req.userId, isAdmin: true },
  });
  if (!admin) return res.status(403).json({ error: 'Only channel admins can broadcast' });

  const { content, type = 'TEXT' } = req.body;
  let mediaUrl: string | undefined;
  if (req.file) mediaUrl = `/uploads/channels/${req.file.filename}`;

  const broadcast = await prisma.broadcast.create({
    data: { channelId: req.params.id, senderId: req.userId!, content, mediaUrl, type: type as any },
    include: { sender: { select: { id: true, name: true, avatar: true } } },
  });

  getIO().to(`channel:${req.params.id}`).emit('new_broadcast', { channelId: req.params.id, broadcast });
  res.status(201).json(broadcast);
});

export default router;
