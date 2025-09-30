import { Router } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

import { prisma } from '../db/client.js';
import { config } from '../config.js';
import { logError, logInfo } from '../logger.js';

const SALT_ROUNDS = 10;
const TOKEN_TTL_SECONDS = 60 * 60 * 24; // 24h

const emailSchema = z
  .string({ required_error: 'Email requis' })
  .trim()
  .min(1, 'Email requis')
  .email('Email invalide')
  .transform((value) => value.toLowerCase());

const passwordSchema = z
  .string({ required_error: 'Mot de passe requis' })
  .min(8, 'Mot de passe trop court (8 caractères minimum)')
  .max(72, 'Mot de passe trop long (72 caractères maximum)');

const nameSchema = z
  .string()
  .trim()
  .min(2, 'Nom trop court')
  .max(80, 'Nom trop long')
  .optional();

const RegisterSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  name: nameSchema,
});

const LoginSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
});

const buildToken = (userId) => {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: TOKEN_TTL_SECONDS });
};

const sanitizeUser = (user) => ({
  id: user.id,
  email: user.email,
  name: user.name,
  displayName: user.displayName,
  avatarUrl: user.avatarUrl,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
});

const formatZodError = (error) => {
  const { fieldErrors, formErrors } = error.flatten();
  const firstFieldError = Object.values(fieldErrors)
    .flat()
    .find((message) => typeof message === 'string' && message.length > 0);
  if (firstFieldError) {
    return firstFieldError;
  }
  return formErrors.find((message) => message.length > 0) || 'Requête invalide';
};

export const authRouter = Router();

authRouter.post('/register', async (req, res, next) => {
  try {
    const parseResult = RegisterSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: formatZodError(parseResult.error),
        },
      });
    }

    const data = parseResult.data;
    const existing = await prisma.user.findUnique({ where: { email: data.email } });
    if (existing) {
      return res.status(409).json({
        error: {
          code: 'user_exists',
          message: 'Un utilisateur avec cet email existe déjà',
        },
      });
    }

    const passwordHash = await bcrypt.hash(data.password, SALT_ROUNDS);

    const user = await prisma.user.create({
      data: {
        email: data.email,
        name: data.name ?? null,
        displayName: data.name ?? data.email.split('@')[0],
        passwordHash,
      },
    });

    logInfo('auth', 'User registered', { userId: user.id, email: user.email });

    const token = buildToken(user.id);

    return res.status(201).json({
      token,
      user: sanitizeUser(user),
    });
  } catch (error) {
    logError('auth', 'Registration failed', error);
    next(error);
  }
});

authRouter.post('/login', async (req, res, next) => {
  try {
    const parseResult = LoginSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: formatZodError(parseResult.error),
        },
      });
    }

    const data = parseResult.data;
    const user = await prisma.user.findUnique({ where: { email: data.email } });

    if (!user) {
      return res.status(401).json({
        error: {
          code: 'invalid_credentials',
          message: 'Identifiants invalides',
        },
      });
    }

    const passwordOk = await bcrypt.compare(data.password, user.passwordHash);

    if (!passwordOk) {
      return res.status(401).json({
        error: {
          code: 'invalid_credentials',
          message: 'Identifiants invalides',
        },
      });
    }

    const token = buildToken(user.id);

    return res.json({
      token,
      user: sanitizeUser(user),
    });
  } catch (error) {
    logError('auth', 'Login failed', error);
    next(error);
  }
});
