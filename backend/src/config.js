import dotenv from 'dotenv';

dotenv.config();

const parseOrigins = (value) => {
  if (!value) return ['http://localhost:3000'];
  return value.split(',').map((origin) => origin.trim()).filter(Boolean);
};

const toInt = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

export const config = {
  port: toInt(process.env.PORT, 5001),
  openaiKey: process.env.OPENAI_API_KEY || '',
  openaiModel: process.env.OPENAI_MODEL || 'gpt-4o-mini',
  corsOrigins: parseOrigins(process.env.CORS_ORIGINS),
  rateLimit: {
    windowMs: toInt(process.env.RATE_LIMIT_WINDOW_MS, 60_000),
    max: toInt(process.env.RATE_LIMIT_MAX, 60),
  },
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
};
