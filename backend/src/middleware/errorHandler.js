import { logError } from '../logger.js';

export const errorHandler = (err, req, res, next) => { // eslint-disable-line no-unused-vars
  const status = err.status || err.statusCode || 500;
  const code = err.code || (status >= 500 ? 'internal_error' : 'request_error');
  const message = err.message || 'Une erreur est survenue';
  const requestId = res.locals.requestId || req.id;

  logError('errorHandler', `${req.method} ${req.originalUrl} -> ${status}`, {
    requestId,
    message: err.message,
    stack: err.stack,
  });

  res.status(status).json({
    error: {
      code,
      message,
    },
    requestId,
  });
};
