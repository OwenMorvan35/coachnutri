import { Router } from 'express';

export const healthRouter = Router();

healthRouter.get('/healthz', (req, res) => {
  res.json({
    ok: true,
    uptime: Number(process.uptime().toFixed(2)),
    now: new Date().toISOString(),
  });
});

healthRouter.get('/readyz', (req, res) => {
  res.json({
    ready: true,
  });
});
