import { Router } from 'express';
import { prisma } from '../db/client.js';
import { logError } from '../logger.js';
import { requireAuth } from '../middleware/auth.js';

export const usersRouter = Router();

usersRouter.use(requireAuth);

usersRouter.get('/me', async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user) {
      return res.status(404).json({
        error: {
          code: 'not_found',
          message: 'Utilisateur introuvable',
        },
      });
    }

    res.json({ user });
  } catch (error) {
    logError('usersRouter', 'Failed to fetch current user', error);
    next(error);
  }
});

usersRouter.get('/', async (req, res, next) => {
  try {
    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
      },
    });
    res.json({ users });
  } catch (error) {
    logError('usersRouter', 'Failed to list users', error);
    next(error);
  }
});

usersRouter.post('/', async (req, res, next) => {
  try {
    return res.status(501).json({
      error: {
        code: 'not_implemented',
        message: 'Utilise /auth/register pour créer un utilisateur',
      },
    });
  } catch (error) {
    logError('usersRouter', 'Failed to create user', error);
    next(error);
  }
});
