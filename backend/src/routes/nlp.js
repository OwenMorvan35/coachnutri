import { Router } from 'express';
import { prisma } from '../db/client.js';
import { requireAuth } from '../middleware/auth.js';
import { logError, logInfo } from '../logger.js';
import {
  WeightValidationError,
  parseWeightCommand,
} from '../services/weightParser.js';
import { invalidateUserCache } from './weights.js';

export const nlpRouter = Router();

nlpRouter.use(requireAuth);

const formatDateForUser = (date) => {
  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(date);
};

nlpRouter.post('/weights/parse-and-log', async (req, res, next) => {
  const userId = req.user.id;
  const body = req.body || {};
  const text = typeof body.text === 'string' ? body.text : typeof body.message === 'string' ? body.message : '';

  try {
    const { weightKg, date } = parseWeightCommand(text, { now: new Date() });
    const note = typeof body.note === 'string' && body.note.trim() ? body.note.trim() : null;

    const entry = await prisma.weightEntry.create({
      data: {
        userId,
        weightKg,
        date,
        note,
        source: 'AI',
      },
    });

    invalidateUserCache(userId);

    logInfo('nlpRouter', 'Weight entry created via NLP', {
      userId,
      entryId: entry.id,
      date: entry.date.toISOString(),
      source: entry.source,
    });

    const formattedDate = formatDateForUser(entry.date);
    const displayWeight = weightKg.toString().replace('.', ',');
    const confirmation = `Parfait ! J'ai enregistré ${displayWeight} kg pour le ${formattedDate}.`;

    return res.json({
      message: confirmation,
      entry: {
        id: entry.id,
        date: entry.date.toISOString(),
        weightKg: Number(entry.weightKg),
        note: entry.note,
        source: entry.source,
        createdAt: entry.createdAt.toISOString(),
        updatedAt: entry.updatedAt.toISOString(),
      },
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
    logError('nlpRouter', 'Failed to parse NLP weight command', error);
    return next(error);
  }
});
