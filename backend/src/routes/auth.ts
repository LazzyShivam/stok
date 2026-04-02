import { Router, Request, Response } from 'express';
import { body, validationResult } from 'express-validator';
import jwt from 'jsonwebtoken';
import prisma from '../config/database';
import { sendOTP, verifyOTP } from '../services/otpService';

const router = Router();

// POST /api/auth/send-otp
router.post('/send-otp',
  body('phone').custom((v) => /^\+?[1-9]\d{6,14}$/.test(v)).withMessage('Valid phone number required'),
  async (req: Request, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { phone } = req.body;
    try {
      await sendOTP(phone);
      res.json({ message: 'OTP sent successfully', phone });
    } catch (err) {
      console.error('[Auth] sendOTP error:', err);
      res.status(500).json({ error: 'Failed to send OTP' });
    }
  }
);

// POST /api/auth/verify-otp
router.post('/verify-otp',
  body('phone').custom((v) => /^\+?[1-9]\d{6,14}$/.test(v)),
  body('otp').isLength({ min: 6, max: 6 }).isNumeric(),
  async (req: Request, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { phone, otp } = req.body;
    try {
      const valid = await verifyOTP(phone, otp);
      if (!valid) return res.status(400).json({ error: 'Invalid or expired OTP' });

      let user = await prisma.user.findUnique({ where: { phone } });
      const isNewUser = !user;

      if (!user) {
        user = await prisma.user.create({ data: { phone } });
      }

      const token = jwt.sign(
        { userId: user.id },
        process.env.JWT_SECRET || 'secret',
        { expiresIn: '30d' }
      );

      res.json({ token, user, isNewUser });
    } catch (err) {
      console.error('[Auth] verifyOTP error:', err);
      res.status(500).json({ error: 'Verification failed' });
    }
  }
);

// POST /api/auth/refresh
router.post('/refresh', async (req: Request, res: Response) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'Token required' });

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET || 'secret') as { userId: string };
    const user = await prisma.user.findUnique({ where: { id: payload.userId } });
    if (!user) return res.status(401).json({ error: 'User not found' });

    const newToken = jwt.sign({ userId: user.id }, process.env.JWT_SECRET || 'secret', { expiresIn: '30d' });
    res.json({ token: newToken, user });
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
});

export default router;
