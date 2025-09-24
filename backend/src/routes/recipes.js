import { Router } from 'express';
import { prisma } from '../db/client.js';
import { logError, logInfo } from '../logger.js';
import { requireAuth } from '../middleware/auth.js';
import { z } from 'zod';

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
        imageUrl: payload.imageUrl ?? null,
        readyInMin: typeof payload.readyInMin === 'number' ? payload.readyInMin : null,
        servings: typeof payload.servings === 'number' ? payload.servings : null,
        tags: Array.isArray(payload.tags) ? payload.tags.map(String) : [],
        ingredientsJson: Array.isArray(payload.ingredients) ? payload.ingredients : null,
        nutrition: payload.nutrition ?? null,
      },
    });

    logInfo('recipesRouter', 'Recipe created', { recipeId: recipe.id, userId: req.user.id });
    res.status(201).json({ recipe });
  } catch (error) {
    logError('recipesRouter', 'Failed to create recipe', error);
    next(error);
  }
});

// Batch upsert from structured LLM payload
const IngredientSchema = z.object({
  name: z.string().min(1),
  qty: z.number().optional(),
  unit: z.string().optional(),
  category: z.string().optional(),
});

const RecipeInputSchema = z.object({
  id: z.string().min(1).optional(), // externalId
  title: z.string().min(1),
  image: z.string().url().optional(),
  readyInMin: z.number().int().optional(),
  servings: z.number().int().optional(),
  tags: z.array(z.string()).optional(),
  ingredients: z.array(IngredientSchema).optional(),
  steps: z.array(z.string()).optional(),
  nutrition: z.record(z.any()).optional(),
});

recipesRouter.post('/upsert-batch', async (req, res, next) => {
  try {
    const items = Array.isArray(req.body?.recipes) ? req.body.recipes : [];
    if (items.length === 0) {
      return res.status(400).json({ error: { code: 'invalid_request', message: 'recipes[] requis' } });
    }
    const parsed = items
      .map((it) => RecipeInputSchema.safeParse(it))
      .filter((r) => r.success)
      .map((r) => r.data);
    const results = [];
    for (const r of parsed) {
      const data = {
        userId: req.user.id,
        externalId: r.id ?? null,
        title: r.title,
        imageUrl: r.image ?? null,
        readyInMin: r.readyInMin ?? null,
        servings: r.servings ?? null,
        tags: r.tags ?? [],
        ingredientsJson: r.ingredients ?? null,
        steps: r.steps ?? [],
        nutrition: r.nutrition ?? null,
      };
      let rec;
      if (r.id) {
        const existing = await prisma.recipe.findFirst({ where: { userId: req.user.id, externalId: r.id } });
        if (existing) {
          rec = await prisma.recipe.update({ where: { id: existing.id }, data });
        } else {
          rec = await prisma.recipe.create({ data });
        }
      } else {
        rec = await prisma.recipe.create({ data });
      }
      results.push(rec);
    }
    return res.status(201).json({ recipes: results });
  } catch (error) {
    logError('recipesRouter', 'Failed to upsert recipe batch', error);
    next(error);
  }
});
