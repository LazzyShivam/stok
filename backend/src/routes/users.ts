import { Router, Response } from 'express';
import { body, query, validationResult } from 'express-validator';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { authenticate, AuthRequest } from '../middleware/auth';
import prisma from '../config/database';

const router = Router();

const storage = multer.diskStorage({
  destination: './uploads/avatars',
  filename: (_req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`),
});
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });

// GET /api/users/me
router.get('/me', authenticate, async (req: AuthRequest, res: Response) => {
  const user = await prisma.user.findUnique({ where: { id: req.userId } });
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json(user);
});

// PATCH /api/users/me
router.patch('/me', authenticate,
  body('name').optional().isString().isLength({ max: 60 }),
  body('bio').optional().isString().isLength({ max: 200 }),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { name, bio } = req.body;
    const user = await prisma.user.update({
      where: { id: req.userId },
      data: { name, bio },
    });
    res.json(user);
  }
);

// POST /api/users/me/avatar
router.post('/me/avatar', authenticate, upload.single('avatar'), async (req: AuthRequest, res: Response) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const avatarUrl = `/uploads/avatars/${req.file.filename}`;
  const user = await prisma.user.update({ where: { id: req.userId }, data: { avatar: avatarUrl } });
  res.json({ avatar: user.avatar });
});

// POST /api/users/me/push-token
router.post('/me/push-token', authenticate,
  body('token').isString(),
  async (req: AuthRequest, res: Response) => {
    const { token } = req.body;
    await prisma.user.update({ where: { id: req.userId }, data: { pushToken: token } });
    res.json({ message: 'Push token updated' });
  }
);

// GET /api/users/search?q=...
router.get('/search', authenticate,
  query('q').isString().isLength({ min: 1 }),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const q = req.query.q as string;
    const users = await prisma.user.findMany({
      where: {
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { phone: { contains: q } },
        ],
        id: { not: req.userId },
      },
      select: { id: true, name: true, phone: true, avatar: true, status: true, isAgent: true },
      take: 20,
    });
    res.json(users);
  }
);

// POST /api/users/batch-check — check which phone numbers are registered on Stok
router.post('/batch-check', authenticate,
  body('phones').isArray({ min: 1, max: 500 }),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { phones } = req.body as { phones: string[] };
    const users = await prisma.user.findMany({
      where: { phone: { in: phones }, isAgent: false },
      select: { id: true, name: true, phone: true, avatar: true, status: true },
    });
    res.json(users);
  }
);

// GET /api/users/:id
router.get('/:id', authenticate, async (req: AuthRequest, res: Response) => {
  const user = await prisma.user.findUnique({
    where: { id: req.params.id },
    select: { id: true, name: true, phone: true, avatar: true, bio: true, status: true, lastSeen: true, isAgent: true, agentConfig: true },
  });
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json(user);
});

export default router;
