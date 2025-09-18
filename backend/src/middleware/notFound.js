import { logInfo } from '../logger.js';

export const notFound = (req, res) => {
  const requestId = res.locals.requestId || req.id;
  logInfo('notFound', `${req.method} ${req.originalUrl} -> 404`, { requestId });
  res.status(404).json({
    error: {
      code: 'not_found',
      message: 'La ressource demandée est introuvable',
    },
    requestId,
  });
};
