import { Router } from 'express';
import { prisma } from '../db/client.js';
import { logError, logInfo } from '../logger.js';
import { requireAuth } from '../middleware/auth.js';

export const shoppingListsRouter = Router();

shoppingListsRouter.use(requireAuth);

shoppingListsRouter.get('/', async (req, res, next) => {
  try {
    const lists = await prisma.shoppingList.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ lists });
  } catch (error) {
    logError('shoppingListsRouter', 'Failed to list shopping lists', error);
    next(error);
  }
});

shoppingListsRouter.post('/', async (req, res, next) => {
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

    const list = await prisma.shoppingList.create({
      data: {
        userId: req.user.id,
        title: payload.title,
        items: Array.isArray(payload.items) ? payload.items : [],
      },
    });

    logInfo('shoppingListsRouter', 'Shopping list created', {
      shoppingListId: list.id,
      userId: req.user.id,
    });
    res.status(201).json({ list });
  } catch (error) {
    logError('shoppingListsRouter', 'Failed to create shopping list', error);
    next(error);
  }
});
