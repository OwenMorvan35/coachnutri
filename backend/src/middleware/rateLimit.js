import rateLimit from 'express-rate-limit';
import { logInfo } from '../logger.js';

export const buildCoachRateLimiter = ({ windowMs, max }) => rateLimit({
  windowMs,
  max,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => { // eslint-disable-line no-unused-vars
    const requestId = res.locals.requestId || req.id;
    logInfo('rateLimit', `${req.ip} hit rate limit`, {
      requestId,
      limit: max,
      windowMs,
    });
    res.status(options.statusCode).json({
      error: {
        code: 'rate_limited',
        message: 'Trop de requêtes, merci de réessayer plus tard',
      },
      requestId,
    });
  },
});
