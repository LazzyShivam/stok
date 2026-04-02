import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { GroupMember } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';
import prisma from '../config/database';
import { getIO } from '../socket';

const router = Router();

const storage = multer.diskStorage({
  destination: './uploads/groups',
  filename: (_req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`),
});
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });

const msgStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const type = file.mimetype.startsWith('image') ? 'images' : file.mimetype.startsWith('audio') ? 'audio' : 'files';
    cb(null, `./uploads/${type}`);
  },
  filename: (_req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`),
});
const msgUpload = multer({ storage: msgStorage, limits: { fileSize: 50 * 1024 * 1024 } });

// GET /api/groups - list user's groups
router.get('/', authenticate, async (req: AuthRequest, res: Response) => {
  const groups = await prisma.group.findMany({
    where: { members: { some: { userId: req.userId } } },
    include: {
      _count: { select: { members: true } },
      members: {
        take: 5,
        include: { user: { select: { id: true, name: true, avatar: true, status: true } } },
      },
    },
    orderBy: { updatedAt: 'desc' },
  });
  res.json(groups);
});

// POST /api/groups - create group
router.post('/', authenticate,
  body('name').isString().isLength({ min: 1, max: 100 }),
  body('memberIds').isArray({ min: 1 }),
  body('description').optional().isString().isLength({ max: 500 }),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { name, description, memberIds } = req.body;
    const allMembers = [...new Set([req.userId!, ...memberIds])];

    const group = await prisma.group.create({
      data: {
        name,
        description,
        creatorId: req.userId!,
        members: {
          create: allMembers.map(userId => ({
            userId,
            role: userId === req.userId ? 'OWNER' : 'MEMBER',
          })),
        },
      },
      include: {
        members: { include: { user: { select: { id: true, name: true, avatar: true } } } },
        _count: { select: { members: true } },
      },
    });

    res.status(201).json(group);
  }
);

// GET /api/groups/:id
router.get('/:id', authenticate, async (req: AuthRequest, res: Response) => {
  const member = await prisma.groupMember.findFirst({ where: { groupId: req.params.id, userId: req.userId } });
  if (!member) return res.status(403).json({ error: 'Access denied' });

  const group = await prisma.group.findUnique({
    where: { id: req.params.id },
    include: {
      members: {
        include: { user: { select: { id: true, name: true, avatar: true, status: true, isAgent: true } } },
      },
    },
  });
  res.json(group);
});

// PATCH /api/groups/:id
router.patch('/:id', authenticate, upload.single('avatar'), async (req: AuthRequest, res: Response) => {
  const member = await prisma.groupMember.findFirst({
    where: { groupId: req.params.id, userId: req.userId, role: { in: ['OWNER', 'ADMIN'] } },
  });
  if (!member) return res.status(403).json({ error: 'Access denied' });

  const { name, description } = req.body;
  const data: any = {};
  if (name) data.name = name;
  if (description) data.description = description;
  if (req.file) data.avatar = `/uploads/groups/${req.file.filename}`;

  const group = await prisma.group.update({ where: { id: req.params.id }, data });
  res.json(group);
});

// POST /api/groups/:id/members - add member
router.post('/:id/members', authenticate,
  body('userId').isUUID(),
  async (req: AuthRequest, res: Response) => {
    const member = await prisma.groupMember.findFirst({
      where: { groupId: req.params.id, userId: req.userId, role: { in: ['OWNER', 'ADMIN'] } },
    });
    if (!member) return res.status(403).json({ error: 'Access denied' });

    const { userId } = req.body;
    await prisma.groupMember.upsert({
      where: { groupId_userId: { groupId: req.params.id, userId } },
      create: { groupId: req.params.id, userId },
      update: {},
    });
    res.json({ message: 'Member added' });
  }
);

// DELETE /api/groups/:id/members/:userId
router.delete('/:id/members/:userId', authenticate, async (req: AuthRequest, res: Response) => {
  const requester = await prisma.groupMember.findFirst({ where: { groupId: req.params.id, userId: req.userId } });
  if (!requester) return res.status(403).json({ error: 'Access denied' });

  const canRemove = requester.role !== 'MEMBER' || req.params.userId === req.userId;
  if (!canRemove) return res.status(403).json({ error: 'Insufficient permissions' });

  await prisma.groupMember.delete({
    where: { groupId_userId: { groupId: req.params.id, userId: req.params.userId } },
  });
  res.json({ message: 'Member removed' });
});

// GET /api/groups/:id/messages
router.get('/:id/messages', authenticate, async (req: AuthRequest, res: Response) => {
  const member = await prisma.groupMember.findFirst({ where: { groupId: req.params.id, userId: req.userId } });
  if (!member) return res.status(403).json({ error: 'Access denied' });

  const { cursor, limit = '50' } = req.query;
  const take = Math.min(parseInt(limit as string, 10), 100);

  // Group messages are stored in conversations linked to group
  // For simplicity, fetch from the group's conversation
  const messages = await prisma.message.findMany({
    where: { metadata: { path: ['groupId'], equals: req.params.id }, isDeleted: false },
    include: {
      sender: { select: { id: true, name: true, avatar: true, isAgent: true } },
      replyTo: { include: { sender: { select: { id: true, name: true } } } },
    },
    orderBy: { createdAt: 'desc' },
    take,
    ...(cursor ? { cursor: { id: cursor as string }, skip: 1 } : {}),
  });
  res.json(messages.reverse());
});

// POST /api/groups/:id/messages
router.post('/:id/messages', authenticate, msgUpload.single('media'), async (req: AuthRequest, res: Response) => {
  const member = await prisma.groupMember.findFirst({ where: { groupId: req.params.id, userId: req.userId } });
  if (!member) return res.status(403).json({ error: 'Access denied' });

  const { content, type = 'TEXT', replyToId } = req.body;
  let mediaUrl: string | undefined;
  if (req.file) {
    const subdir = req.file.mimetype.startsWith('image') ? 'images' : req.file.mimetype.startsWith('audio') ? 'audio' : 'files';
    mediaUrl = `/uploads/${subdir}/${req.file.filename}`;
  }

  // We use a shared conversation for the group, or create one
  let conv = await prisma.conversation.findFirst({
    where: { messages: { some: { metadata: { path: ['groupId'], equals: req.params.id } } } },
  });
  if (!conv) {
    const group = await prisma.group.findUnique({ where: { id: req.params.id }, include: { members: true } });
    conv = await prisma.conversation.create({
      data: {
        members: { create: group!.members.map((m: GroupMember) => ({ userId: m.userId })) },
      },
    });
  }

  const message = await prisma.message.create({
    data: {
      conversationId: conv.id,
      senderId: req.userId!,
      content,
      type: type as any,
      mediaUrl,
      replyToId: replyToId || null,
      metadata: { groupId: req.params.id },
    },
    include: {
      sender: { select: { id: true, name: true, avatar: true, isAgent: true } },
      replyTo: { include: { sender: { select: { id: true, name: true } } } },
    },
  });

  getIO().to(`group:${req.params.id}`).emit('new_group_message', { groupId: req.params.id, message });
  res.status(201).json(message);
});

export default router;
