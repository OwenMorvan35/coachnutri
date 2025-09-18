import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { logError, logInfo } from '../logger.js';

const extractToken = (headerValue = '') => {
  if (typeof headerValue !== 'string') {
    return null;
  }
  const [scheme, token] = headerValue.split(' ');
  if (!scheme || !token) {
    return null;
  }
  return scheme.toLowerCase() === 'bearer' ? token.trim() : null;
};

export const requireAuth = (req, res, next) => {
  const requestId = res.locals.requestId || req.id;
  const token = extractToken(req.headers.authorization);

  if (!token) {
    logInfo('authMiddleware', 'Missing bearer token', { requestId });
    return res.status(401).json({
      error: {
        code: 'unauthorized',
        message: 'Token absent ou invalide',
      },
      requestId,
    });
  }

  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.user = { id: payload.sub };
    return next();
  } catch (error) {
    logError('authMiddleware', 'Token verification failed', error);
    return res.status(401).json({
      error: {
        code: 'unauthorized',
        message: 'Token invalide ou expiré',
      },
      requestId,
    });
  }
};
