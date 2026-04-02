import { Router, Response } from 'express';
import { body, validationResult } from 'express-validator';
import { authenticate, AuthRequest } from '../middleware/auth';
import prisma from '../config/database';
import { generateAgentResponse } from '../services/aiService';

const router = Router();

// GET /api/agents - list all AI agents
router.get('/', authenticate, async (_req: AuthRequest, res: Response) => {
  const agents = await prisma.user.findMany({
    where: { isAgent: true },
    select: { id: true, name: true, avatar: true, bio: true, agentConfig: true, status: true },
  });
  res.json(agents);
});

// POST /api/agents - create AI agent
router.post('/', authenticate,
  body('name').isString().isLength({ min: 1, max: 60 }),
  body('systemPrompt').isString().isLength({ min: 10, max: 2000 }),
  body('bio').optional().isString().isLength({ max: 200 }),
  body('model').optional().isString(),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { name, systemPrompt, bio, model = 'claude-sonnet-4-6' } = req.body;

    const agent = await prisma.user.create({
      data: {
        phone: `agent_${Date.now()}`,
        name,
        bio,
        isAgent: true,
        status: 'ONLINE',
        agentConfig: { systemPrompt, model, createdBy: req.userId },
      },
    });
    res.status(201).json(agent);
  }
);

// GET /api/agents/:id
router.get('/:id', authenticate, async (req: AuthRequest, res: Response) => {
  const agent = await prisma.user.findFirst({
    where: { id: req.params.id, isAgent: true },
    select: { id: true, name: true, avatar: true, bio: true, agentConfig: true, status: true },
  });
  if (!agent) return res.status(404).json({ error: 'Agent not found' });
  res.json(agent);
});

// PATCH /api/agents/:id
router.patch('/:id', authenticate,
  body('name').optional().isString(),
  body('systemPrompt').optional().isString(),
  body('bio').optional().isString(),
  body('model').optional().isString(),
  async (req: AuthRequest, res: Response) => {
    const agent = await prisma.user.findFirst({ where: { id: req.params.id, isAgent: true } });
    if (!agent) return res.status(404).json({ error: 'Agent not found' });

    const config = (agent.agentConfig as any) || {};
    if ((config as any).createdBy !== req.userId) return res.status(403).json({ error: 'Access denied' });

    const { name, systemPrompt, bio, model } = req.body;
    const updatedAgent = await prisma.user.update({
      where: { id: req.params.id },
      data: {
        name: name || agent.name,
        bio: bio || agent.bio,
        agentConfig: {
          ...config,
          ...(systemPrompt && { systemPrompt }),
          ...(model && { model }),
        },
      },
    });
    res.json(updatedAgent);
  }
);

// DELETE /api/agents/:id
router.delete('/:id', authenticate, async (req: AuthRequest, res: Response) => {
  const agent = await prisma.user.findFirst({ where: { id: req.params.id, isAgent: true } });
  if (!agent) return res.status(404).json({ error: 'Agent not found' });
  const config = (agent.agentConfig as any) || {};
  if (config.createdBy !== req.userId) return res.status(403).json({ error: 'Access denied' });
  await prisma.user.delete({ where: { id: req.params.id } });
  res.json({ message: 'Agent deleted' });
});

// POST /api/agents/:id/chat - direct chat with agent (non-streaming)
router.post('/:id/chat', authenticate,
  body('message').isString().isLength({ min: 1 }),
  body('history').optional().isArray(),
  async (req: AuthRequest, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const agent = await prisma.user.findFirst({ where: { id: req.params.id, isAgent: true } });
    if (!agent) return res.status(404).json({ error: 'Agent not found' });

    const config = agent.agentConfig as any;
    const { message, history = [] } = req.body;

    const response = await generateAgentResponse(
      { model: config.model, systemPrompt: config.systemPrompt, name: agent.name },
      history,
      message
    );

    res.json({ response, agentId: agent.id });
  }
);

export default router;
