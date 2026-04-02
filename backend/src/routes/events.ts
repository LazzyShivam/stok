import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { authenticate, AuthRequest } from '../middleware/auth';
import prisma from '../config/database';
import { getIO } from '../socket';

const router = Router();

// GET /api/events - list user's events
router.get('/', authenticate, async (req: AuthRequest, res: Response) => {
  const events = await prisma.event.findMany({
    where: {
      OR: [
        { creatorId: req.userId },
        { attendees: { some: { userId: req.userId } } },
      ],
    },
    include: {
      creator: { select: { id: true, name: true, avatar: true } },
      _count: { select: { attendees: true } },
      attendees: { where: { userId: req.userId }, take: 1 },
    },
    orderBy: { startTime: 'asc' },
  });
  res.json(events);
});

// POST /api/events - create event
router.post('/', authenticate,
  body('title').isString().isLength({ min: 1, max: 200 }),
  body('startTime').isISO8601(),
  body('endTime').isISO8601(),
  body('description').optional().isString(),
  body('location').optional().isString(),
  body('groupId').optional().isUUID(),
  body('channelId').optional().isUUID(),
  body('invitees').optional().isArray(),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { title, description, startTime, endTime, location, groupId, channelId, invitees = [] } = req.body;

    const event = await prisma.event.create({
      data: {
        title,
        description,
        startTime: new Date(startTime),
        endTime: new Date(endTime),
        location,
        creatorId: req.userId!,
        groupId: groupId || null,
        channelId: channelId || null,
        attendees: {
          create: [
            { userId: req.userId!, status: 'ACCEPTED' },
            ...invitees.map((id: string) => ({ userId: id, status: 'PENDING' })),
          ],
        },
      },
      include: {
        creator: { select: { id: true, name: true, avatar: true } },
        attendees: { include: { user: { select: { id: true, name: true, avatar: true } } } },
      },
    });

    // Notify invitees via socket
    invitees.forEach((userId: string) => {
      getIO().to(`user:${userId}`).emit('event_invite', { event });
    });

    res.status(201).json(event);
  }
);

// GET /api/events/:id
router.get('/:id', authenticate, async (req: AuthRequest, res: Response) => {
  const event = await prisma.event.findUnique({
    where: { id: req.params.id },
    include: {
      creator: { select: { id: true, name: true, avatar: true } },
      attendees: { include: { user: { select: { id: true, name: true, avatar: true, status: true } } } },
    },
  });
  if (!event) return res.status(404).json({ error: 'Event not found' });
  res.json(event);
});

// PATCH /api/events/:id/rsvp
router.patch('/:id/rsvp', authenticate,
  body('status').isIn(['ACCEPTED', 'DECLINED']),
  async (req: AuthRequest, res: Response) => {
    const { status } = req.body;
    const attendee = await prisma.eventAttendee.upsert({
      where: { eventId_userId: { eventId: req.params.id, userId: req.userId! } },
      create: { eventId: req.params.id, userId: req.userId!, status },
      update: { status },
    });
    res.json(attendee);
  }
);

// DELETE /api/events/:id
router.delete('/:id', authenticate, async (req: AuthRequest, res: Response) => {
  const event = await prisma.event.findFirst({ where: { id: req.params.id, creatorId: req.userId } });
  if (!event) return res.status(404).json({ error: 'Event not found or access denied' });
  await prisma.event.delete({ where: { id: req.params.id } });
  res.json({ message: 'Event deleted' });
});

export default router;
