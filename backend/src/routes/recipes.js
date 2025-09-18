import { Router } from 'express';
import { prisma } from '../db/client.js';
import { logError, logInfo } from '../logger.js';
import { requireAuth } from '../middleware/auth.js';

export const recipesRouter = Router();

recipesRouter.use(requireAuth);

recipesRouter.get('/', async (req, res, next) => {
  try {
    const recipes = await prisma.recipe.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ recipes });
  } catch (error) {
    logError('recipesRouter', 'Failed to list recipes', error);
    next(error);
  }
});

recipesRouter.post('/', async (req, res, next) => {
  try {
    const payload = req.body || {};
    if (!payload.title) {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: 'title est requis',
        },
      });
    }

    const recipe = await prisma.recipe.create({
      data: {
        userId: req.user.id,
        title: payload.title,
        description: payload.description ?? null,
        steps: Array.isArray(payload.steps) ? payload.steps : [],
      },
    });

    logInfo('recipesRouter', 'Recipe created', { recipeId: recipe.id, userId: req.user.id });
    res.status(201).json({ recipe });
  } catch (error) {
    logError('recipesRouter', 'Failed to create recipe', error);
    next(error);
  }
});
