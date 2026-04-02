import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { CallParticipant } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';
import prisma from '../config/database';
import { getIO } from '../socket';

const router = Router();

// POST /api/calls/initiate
router.post('/initiate', authenticate,
  body('targetUserId').isUUID(),
  body('type').isIn(['VOICE', 'VIDEO']),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { targetUserId, type } = req.body;

    const call = await prisma.call.create({
      data: {
        type: type as any,
        status: 'INITIATED',
        participants: { create: [{ userId: req.userId! }, { userId: targetUserId }] },
      },
    });

    // Notify target user via socket
    getIO().to(`user:${targetUserId}`).emit('incoming_call', {
      callId: call.id,
      callType: type,
      callerId: req.userId,
    });

    res.status(201).json({ callId: call.id });
  }
);

// PATCH /api/calls/:id/status
router.patch('/:id/status', authenticate,
  body('status').isIn(['ACTIVE', 'ENDED', 'REJECTED', 'MISSED']),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { status } = req.body;
    const data: any = { status };
    if (status === 'ACTIVE') data.startedAt = new Date();
    if (['ENDED', 'REJECTED', 'MISSED'].includes(status)) data.endedAt = new Date();

    const call = await prisma.call.update({ where: { id: req.params.id }, data });

    // Notify all participants
    const participants = await prisma.callParticipant.findMany({ where: { callId: req.params.id } });
    participants.forEach((p: CallParticipant) => {
      getIO().to(`user:${p.userId}`).emit('call_status_changed', { callId: req.params.id, status });
    });

    res.json(call);
  }
);

export default router;
