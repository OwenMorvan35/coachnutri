import { Router } from 'express';
import { config } from '../config.js';
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

  const trimmedHistory = Array.isArray(data.history) && data.history.length > 0
    ? data.history.slice(-12)
    : [];

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
