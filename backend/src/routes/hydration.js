import { Router } from 'express';
import { z } from 'zod';

import { prisma } from '../db/client.js';
import { requireAuth } from '../middleware/auth.js';
import { logError, logInfo } from '../logger.js';

export const hydrationRouter = Router();

hydrationRouter.use(requireAuth);

const HYDRATION_RESET_INTERVAL_MS = 24 * 60 * 60 * 1000;
const HYDRATION_COOLDOWN_MS = 60 * 60 * 1000;

const serializeHydration = (state, { now = new Date() } = {}) => {
  const ratio = state.dailyGoalMl > 0 ? state.consumedMl / state.dailyGoalMl : 0;
  const lastIntakeAt = state.lastIntakeAt ? new Date(state.lastIntakeAt) : null;
  const nextAvailableAt = lastIntakeAt
    ? new Date(lastIntakeAt.getTime() + HYDRATION_COOLDOWN_MS)
    : null;
  const remainingMs = nextAvailableAt && nextAvailableAt > now
    ? nextAvailableAt.getTime() - now.getTime()
    : 0;

  return {
    id: state.id,
    userId: state.userId,
    consumedMl: state.consumedMl,
    dailyGoalMl: state.dailyGoalMl,
    lastResetAt: state.lastResetAt.toISOString(),
    createdAt: state.createdAt.toISOString(),
    updatedAt: state.updatedAt.toISOString(),
    hydrationPercent: Math.max(0, ratio * 100),
    progress: Math.min(Math.max(ratio, 0), 1),
    lastIntakeAt: lastIntakeAt ? lastIntakeAt.toISOString() : null,
    nextAvailableAt: nextAvailableAt ? nextAvailableAt.toISOString() : null,
    cooldownMs: HYDRATION_COOLDOWN_MS,
    cooldownRemainingMs: remainingMs > 0 ? remainingMs : 0,
  };
};

const ensureHydrationState = async (tx, userId, { now = new Date() } = {}) => {
  let state = await tx.hydrationState.findUnique({ where: { userId } });
  if (!state) {
    state = await tx.hydrationState.create({
      data: {
        userId,
        consumedMl: 0,
        dailyGoalMl: 2000,
        lastResetAt: now,
        lastIntakeAt: null,
      },
    });
    return state;
  }

  const needsReset = now.getTime() - state.lastResetAt.getTime() >= HYDRATION_RESET_INTERVAL_MS;
  if (needsReset) {
    state = await tx.hydrationState.update({
      where: { userId },
      data: {
        consumedMl: 0,
        lastResetAt: now,
        lastIntakeAt: null,
      },
    });
  }
  return state;
};

hydrationRouter.get('/', async (req, res, next) => {
  const userId = req.user.id;
  const now = new Date();

  try {
    const state = await prisma.$transaction((tx) => ensureHydrationState(tx, userId, { now }));
    return res.json({ hydration: serializeHydration(state, { now }) });
  } catch (error) {
    logError('hydrationRouter', `Failed to fetch hydration state for ${userId}`, error);
    return next(error);
  }
});

const intakeSchema = z.object({
  amount: z
    .number({ required_error: 'Amount is required' })
    .int('La quantité doit être un nombre entier (ml)')
    .min(10, 'La quantité doit être d\'au moins 10 ml')
    .max(5000, 'La quantité dépasse la limite autorisée (5 L)'),
});

hydrationRouter.post('/intake', async (req, res, next) => {
  const userId = req.user.id;
  const now = new Date();

  const parsed = intakeSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    return res.status(400).json({
      error: {
        code: 'invalid_request',
        message: parsed.error.errors[0]?.message ?? 'Requête invalide',
      },
    });
  }

  const { amount } = parsed.data;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const state = await ensureHydrationState(tx, userId, { now });
      const lastIntakeAt = state.lastIntakeAt ? new Date(state.lastIntakeAt) : null;
      const nextAvailableAt = lastIntakeAt
        ? new Date(lastIntakeAt.getTime() + HYDRATION_COOLDOWN_MS)
        : null;

      if (nextAvailableAt && nextAvailableAt > now) {
        return { blocked: true, state, nextAvailableAt };
      }

      const updated = await tx.hydrationState.update({
        where: { userId },
        data: {
          consumedMl: { increment: amount },
          lastIntakeAt: now,
        },
      });

      return { blocked: false, state: updated };
    });

    if (result.blocked) {
      const { state, nextAvailableAt } = result;
      const remainingMs = Math.max(0, nextAvailableAt.getTime() - now.getTime());
      const retrySeconds = Math.max(1, Math.ceil(remainingMs / 1000));
      const remainingMinutes = Math.max(1, Math.ceil(remainingMs / 60000));
      res.set('Retry-After', String(retrySeconds));
      return res.status(429).json({
        error: {
          code: 'cooldown_active',
          message: `Patiente encore ${remainingMinutes} min avant d'ajouter de l'eau.`,
          retryAfterMs: remainingMs,
          nextAvailableAt: nextAvailableAt.toISOString(),
        },
        hydration: serializeHydration(state, { now }),
      });
    }

    logInfo('hydrationRouter', 'Hydration intake recorded', { userId, amount });
    return res.status(201).json({
      hydration: serializeHydration(result.state, { now }),
      message: 'Hydratation mise à jour.',
    });
  } catch (error) {
    logError('hydrationRouter', `Failed to record hydration intake for ${userId}`, error);
    return next(error);
  }
});

const goalSchema = z.object({
  dailyGoalMl: z
    .number({ required_error: 'L\'objectif est requis' })
    .int('L\'objectif doit être un entier (ml)')
    .min(500, 'L\'objectif doit être d\'au moins 500 ml')
    .max(10000, 'L\'objectif ne peut pas dépasser 10 L'),
});

hydrationRouter.patch('/', async (req, res, next) => {
  const userId = req.user.id;
  const now = new Date();

  const parsed = goalSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    return res.status(400).json({
      error: {
        code: 'invalid_request',
        message: parsed.error.errors[0]?.message ?? 'Requête invalide',
      },
    });
  }

  const { dailyGoalMl } = parsed.data;

  try {
    const state = await prisma.$transaction(async (tx) => {
      await ensureHydrationState(tx, userId, { now });
      return tx.hydrationState.update({
        where: { userId },
        data: {
          dailyGoalMl,
        },
      });
    });

    logInfo('hydrationRouter', 'Hydration goal updated', { userId, dailyGoalMl });
    return res.json({
      hydration: serializeHydration(state, { now }),
      message: 'Objectif hydratation mis à jour.',
    });
  } catch (error) {
    logError('hydrationRouter', `Failed to update hydration goal for ${userId}`, error);
    return next(error);
  }
});

export default hydrationRouter;
