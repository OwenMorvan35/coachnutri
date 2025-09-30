import { Router } from 'express';
import { prisma } from '../db/client.js';
import { requireAuth } from '../middleware/auth.js';
import { logError, logInfo } from '../logger.js';
import {
  WeightValidationError,
  aggregateEntries,
  computeStats,
  getRangeBounds,
  parseDateInput,
  parseWeightValue,
} from '../services/weightParser.js';

const CACHE_TTL_MS = 30_000;
const cache = new Map();

const buildCacheKey = (userId, range, aggregate) => `${userId}:${range}:${aggregate}`;

const getCached = (key) => {
  const cached = cache.get(key);
  if (!cached) {
    return null;
  }
  if (Date.now() - cached.ts > CACHE_TTL_MS) {
    cache.delete(key);
    return null;
  }
  return cached.payload;
};

const setCached = (key, payload) => {
  cache.set(key, { ts: Date.now(), payload });
};

export const invalidateUserCache = (userId) => {
  for (const key of cache.keys()) {
    if (key.startsWith(`${userId}:`)) {
      cache.delete(key);
    }
  }
};

const normalizeRange = (value = 'week') => {
  const normalized = String(value).toLowerCase();
  if (['day', 'jour'].includes(normalized)) {
    return 'day';
  }
  if (['month', 'mois'].includes(normalized)) {
    return 'month';
  }
  if (['year', 'annee'].includes(normalized)) {
    return 'year';
  }
  return 'week';
};

const normalizeAggregate = (value = 'latest') => {
  const normalized = String(value).toLowerCase();
  if (['avg', 'average', 'moyenne'].includes(normalized)) {
    return 'avg';
  }
  return 'latest';
};

export const weightsRouter = Router();

weightsRouter.use(requireAuth);

weightsRouter.get('/', async (req, res, next) => {
  const userId = req.user.id;
  const range = normalizeRange(req.query.range || 'week');
  const aggregate = normalizeAggregate(req.query.aggregate || 'latest');
  const cacheKey = buildCacheKey(userId, range, aggregate);

  const cached = getCached(cacheKey);
  if (cached) {
    return res.json({ ...cached, cached: true });
  }

  try {
    const { start, end } = getRangeBounds(range, { now: new Date() });
    const rows = await prisma.weightEntry.findMany({
      where: {
        userId,
        date: {
          gte: start,
          lte: end,
        },
      },
      orderBy: { date: 'asc' },
    });

    const plainEntries = rows.map((row) => ({
      id: row.id,
      date: row.date,
      weightKg: Number(row.weightKg),
      note: row.note,
      source: row.source,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    }));

    const points = aggregateEntries(plainEntries, aggregate);
    const stats = computeStats(points);

    const responsePayload = {
      range,
      aggregate,
      entries: points,
      stats,
      meta: {
        start: start.toISOString(),
        end: end.toISOString(),
        totalRaw: rows.length,
        totalReturned: points.length,
      },
    };

    setCached(cacheKey, responsePayload);

    return res.json(responsePayload);
  } catch (error) {
    logError('weightsRouter', 'Failed to fetch weights', error);
    return next(error);
  }
});

weightsRouter.post('/', async (req, res, next) => {
  const userId = req.user.id;
  const body = req.body || {};

  try {
    const now = new Date();
    const weightKg = parseWeightValue(body.weight ?? body.weightKg ?? body.value);
    const date = parseDateInput(body.date, { now });
    const note = typeof body.note === 'string' && body.note.trim() ? body.note.trim() : null;

    const entry = await prisma.weightEntry.create({
      data: {
        userId,
        weightKg,
        date,
        note,
        source: 'MANUAL',
      },
    });

    invalidateUserCache(userId);

    logInfo('weightsRouter', 'Weight entry created', {
      userId,
      entryId: entry.id,
      date: entry.date.toISOString(),
      source: entry.source,
    });

    return res.status(201).json({
      entry: {
        id: entry.id,
        date: entry.date.toISOString(),
        weightKg: Number(entry.weightKg),
        note: entry.note,
        source: entry.source,
        createdAt: entry.createdAt.toISOString(),
        updatedAt: entry.updatedAt.toISOString(),
      },
      message: 'Mesure enregistrée avec succès.',
    });
  } catch (error) {
    if (error instanceof WeightValidationError) {
      return res.status(400).json({
        error: {
          code: error.code,
          message: error.message,
        },
      });
    }
    logError('weightsRouter', 'Failed to create weight entry', error);
    return next(error);
  }
});
