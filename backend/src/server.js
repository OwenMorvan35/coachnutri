import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import { fileURLToPath } from 'node:url';
import { resolve, join } from 'node:path';

import { config } from './config.js';
import { logInfo } from './logger.js';
import { requestId } from './middleware/requestId.js';
import { errorHandler } from './middleware/errorHandler.js';
import { notFound } from './middleware/notFound.js';
import { buildCoachRateLimiter } from './middleware/rateLimit.js';
import { healthRouter } from './routes/health.js';
import { coachRouter } from './routes/coach.js';
import { usersRouter } from './routes/users.js';
import { recipesRouter } from './routes/recipes.js';
import { shoppingListsRouter } from './routes/shoppingLists.js';
import { weightsRouter } from './routes/weights.js';
import { nlpRouter } from './routes/nlp.js';
import { authRouter } from './routes/auth.js';

const app = express();

app.disable('x-powered-by');
app.use(helmet());
app.use(requestId);

morgan.token('request-id', (req) => req.id || '');
app.use(
  morgan((tokens, req, res) => {
    const message = `${tokens.method(req, res)} ${tokens.url(req, res)} ${tokens.status(req, res)} - ${tokens['response-time'](req, res)} ms`;
    logInfo('http', message, { requestId: req.id || res.locals.requestId });
    return null;
  })
);

const corsOrigins = new Set(config.corsOrigins);
const corsOptions = {
  origin(origin, callback) {
    if (!origin) {
      return callback(null, true);
    }
    if (/^http:\/\/localhost(?::\d+)?$/i.test(origin)) {
      return callback(null, true);
    }
    if (corsOrigins.has(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Origin not allowed'));
  },
};

app.use(cors(corsOptions));
app.use(express.json({ limit: '1mb' }));
app.use('/uploads', express.static(join(process.cwd(), 'uploads')));

app.use(healthRouter);
app.use('/coach', buildCoachRateLimiter(config.rateLimit), coachRouter);
app.use('/auth', authRouter);
app.use('/users', usersRouter);
app.use('/recipes', recipesRouter);
app.use('/shopping-lists', shoppingListsRouter);
app.use('/weights', weightsRouter);
app.use('/nlp', nlpRouter);

app.use(notFound);
app.use(errorHandler);

export const server = app;

const isDirectExecution = () => {
  const entry = process.argv[1];
  if (!entry) return false;
  const modulePath = fileURLToPath(import.meta.url);
  return resolve(entry) === modulePath;
};

if (isDirectExecution()) {
  app.listen(config.port, () => {
    logInfo('server', `Serveur démarré sur le port ${config.port}`, {
      port: config.port,
      mode: config.openaiKey ? 'openai' : 'mock',
    });
  });
}
