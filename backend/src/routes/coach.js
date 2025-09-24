import { Router } from 'express';
import { config } from '../config.js';
import { prisma } from '../db/client.js';
import jwt from 'jsonwebtoken';
import { requireAuth } from '../middleware/auth.js';
import { logInfo, logError } from '../logger.js';
import { validateCoachRequest } from '../utils/validate.js';
import { callOpenAI, mockReply } from '../services/llm.js';

export const coachRouter = Router();

const formatValidationError = (error) => {
  const fieldErrors = Object.entries(error.fieldErrors || {})
    .flatMap(([field, messages]) => (messages || []).map((msg) => `${field}: ${msg}`));
  const formErrors = error.formErrors || [];
  const combined = [...formErrors, ...fieldErrors];
  return combined.length > 0 ? combined.join(' | ') : 'Requête invalide';
};

const previewMessage = (value) => {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.length > 120 ? `${trimmed.slice(0, 120)}…` : trimmed;
};

const maybeGetUserId = (req) => {
  try {
    const auth = req.headers?.authorization || '';
    const [scheme, token] = auth.split(' ');
    if (scheme?.toLowerCase() !== 'bearer' || !token) return null;
    const payload = jwt.verify(token, config.jwtSecret);
    return payload?.sub || null;
  } catch (_) {
    return null;
  }
};

coachRouter.post('/', async (req, res, next) => {
  const requestId = res.locals.requestId || req.id;
  const { data, error } = validateCoachRequest(req.body);

  logInfo('coachRoute', 'Requête coach reçue', {
    requestId,
    messagePreview: previewMessage(req.body?.message),
    historySize: Array.isArray(req.body?.history) ? req.body.history.length : 0,
    hasProfile: Boolean(req.body?.profile),
  });

  if (error) {
    const validationMessage = formatValidationError(error);
    logInfo('coachRoute', 'Validation échouée', {
      requestId,
      error: validationMessage,
    });
    return res.status(400).json({
      error: {
        code: 'invalid_request',
        message: validationMessage,
      },
      requestId,
    });
  }

  const userId = maybeGetUserId(req);
  let trimmedHistory = [];
  if (userId) {
    // Fetch last 30 messages from DB and map to roles expected by LLM
    const dbHistDesc = await prisma.chatMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 30,
    });
    const dbHist = dbHistDesc.reverse();
    trimmedHistory = dbHist.map((m) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: m.content,
    }));
  } else if (Array.isArray(data.history) && data.history.length > 0) {
    trimmedHistory = data.history.slice(-30);
  }

  const started = Date.now();

  try {
    logInfo('coachRoute', 'Traitement coach démarré', {
      requestId,
      using: config.openaiKey ? 'openai' : 'mock',
    });
    let llmResult;
    if (config.openaiKey) {
      llmResult = await callOpenAI({
        message: data.message,
        history: trimmedHistory,
        profile: data.profile,
        model: config.openaiModel,
        apiKey: config.openaiKey,
      });
    } else {
      llmResult = await mockReply({
        message: data.message,
        profile: data.profile,
      });
    }

    const durationMs = Date.now() - started;

    logInfo('coachRoute', 'Réponse générée', {
      requestId,
      historySize: trimmedHistory.length,
      source: llmResult.from,
      durationMs,
    });

    // Persist messages if authenticated
    if (userId) {
      try {
        await prisma.$transaction([
          prisma.chatMessage.create({ data: { userId, role: 'user', content: data.message } }),
          prisma.chatMessage.create({ data: { userId, role: 'assistant', content: llmResult.reply } }),
        ]);
      } catch (e) {
        logError('coachRoute', 'Failed to persist chat messages', e);
      }
    }

    return res.json({
      reply: llmResult.reply,
      meta: {
        model: llmResult.model,
        tokens: llmResult.tokens ?? null,
        duration_ms: durationMs,
        from: llmResult.from,
      },
      requestId,
    });
  } catch (err) {
    err.status = err.status || 502;
    err.code = err.code || 'llm_error';
    err.requestId = requestId;
    logError('coachRoute', 'Erreur lors du traitement de la requête coach', err);
    return next(err);
  }
});

// Return last N messages for the current user (default 30)
coachRouter.get('/history', requireAuth, async (req, res, next) => {
  try {
    const limit = Math.max(1, Math.min(50, Number.parseInt(req.query.limit, 10) || 30));
    const rows = await prisma.chatMessage.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
    const messages = rows.map((m) => ({
      role: m.role === 'assistant' ? 'coach' : 'user',
      content: m.content,
      createdAt: m.createdAt,
    }));
    res.json({ messages });
  } catch (error) {
    logError('coachRoute', 'Failed to fetch history', error);
    next(error);
  }
});
