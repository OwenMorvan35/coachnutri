import { Router } from 'express';
import { prisma } from '../db/client.js';
import { logError, logInfo } from '../logger.js';
import { requireAuth } from '../middleware/auth.js';
import { z } from 'zod';
import bcrypt from 'bcrypt';
import multer from 'multer';
import { mkdir, writeFile, unlink, access } from 'node:fs/promises';
import { constants as fsConstants } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { nanoid } from 'nanoid';

export const usersRouter = Router();

usersRouter.use(requireAuth);

const uploadsRoot = resolve(process.cwd(), 'uploads');
const avatarsDir = join(uploadsRoot, 'avatars');
const allowedAvatarMime = new Map([
  ['image/jpeg', 'jpg'],
  ['image/jpg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
  ['image/gif', 'gif'],
]);

const ensureUploadsDir = async () => {
  await mkdir(avatarsDir, { recursive: true });
};

const removeFileIfExists = async (filePath) => {
  try {
    await access(filePath, fsConstants.F_OK);
    await unlink(filePath);
  } catch (_) {
    // ignore if file does not exist
  }
};

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 4 * 1024 * 1024 },
});

const profileSchema = z
  .object({
    displayName: z
      .string({ required_error: 'Le pseudo est requis' })
      .trim()
      .min(2, 'Le pseudo est trop court')
      .max(60, 'Le pseudo est trop long')
      .optional(),
    name: z
      .string()
      .trim()
      .min(2, 'Le nom est trop court')
      .max(80, 'Le nom est trop long')
      .optional(),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: 'Aucune donnée à mettre à jour',
  });

const passwordSchema = z.object({
  currentPassword: z
    .string({ required_error: 'Mot de passe actuel requis' })
    .min(8, 'Mot de passe actuel trop court'),
  newPassword: z
    .string({ required_error: 'Nouveau mot de passe requis' })
    .min(8, 'Nouveau mot de passe trop court')
    .max(72, 'Nouveau mot de passe trop long'),
});

const serializeUser = (user) => ({
  id: user.id,
  email: user.email,
  name: user.name,
  displayName: user.displayName,
  avatarUrl: user.avatarUrl,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
});

usersRouter.get('/me', async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        name: true,
        displayName: true,
        avatarUrl: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user) {
      return res.status(404).json({
        error: {
          code: 'not_found',
          message: 'Utilisateur introuvable',
        },
      });
    }

    res.json({ user: serializeUser(user) });
  } catch (error) {
    logError('usersRouter', 'Failed to fetch current user', error);
    next(error);
  }
});

usersRouter.put('/me', async (req, res, next) => {
  try {
    const parsed = profileSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: parsed.error.errors[0]?.message ?? 'Requête invalide',
        },
      });
    }

    const payload = parsed.data;
    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: {
        ...(payload.displayName != null ? { displayName: payload.displayName } : {}),
        ...(payload.name != null ? { name: payload.name } : {}),
      },
    });

    logInfo('usersRouter', 'User profile updated', { userId: req.user.id });

    res.json({ user: serializeUser(user) });
  } catch (error) {
    logError('usersRouter', 'Failed to update profile', error);
    next(error);
  }
});

usersRouter.post('/me/password', async (req, res, next) => {
  try {
    const parsed = passwordSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: parsed.error.errors[0]?.message ?? 'Requête invalide',
        },
      });
    }

    const { currentPassword, newPassword } = parsed.data;
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user) {
      return res.status(404).json({
        error: {
          code: 'not_found',
          message: 'Utilisateur introuvable',
        },
      });
    }

    const passwordOk = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!passwordOk) {
      return res.status(400).json({
        error: {
          code: 'invalid_credentials',
          message: 'Mot de passe actuel incorrect',
        },
      });
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id: req.user.id },
      data: { passwordHash },
    });

    logInfo('usersRouter', 'Password updated', { userId: req.user.id });

    res.status(204).send();
  } catch (error) {
    logError('usersRouter', 'Failed to update password', error);
    next(error);
  }
});

usersRouter.post('/me/avatar', upload.single('avatar'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        error: { code: 'invalid_request', message: 'Aucun fichier reçu' },
      });
    }

    if (!allowedAvatarMime.has(req.file.mimetype)) {
      return res.status(400).json({
        error: { code: 'unsupported_type', message: 'Format d\'image non supporté' },
      });
    }

    await ensureUploadsDir();
    const mappedExt = allowedAvatarMime.get(req.file.mimetype);
    const fileExt = extname(req.file.originalname || '').replace('.', '');
    const extension = mappedExt ?? (fileExt || 'jpg');
    const filename = `${nanoid(16)}.${extension}`;
    const filePath = join(avatarsDir, filename);

    await writeFile(filePath, req.file.buffer);

    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user) {
      await removeFileIfExists(filePath);
      return res.status(404).json({
        error: { code: 'not_found', message: 'Utilisateur introuvable' },
      });
    }

    if (user.avatarUrl && user.avatarUrl.startsWith('/uploads/avatars/')) {
      const relativePath = user.avatarUrl.replace('/uploads/', '');
      const previousPath = join(uploadsRoot, relativePath);
      await removeFileIfExists(previousPath);
    }

    const publicPath = `/uploads/avatars/${filename}`;

    const updated = await prisma.user.update({
      where: { id: req.user.id },
      data: { avatarUrl: publicPath },
    });

    logInfo('usersRouter', 'Avatar updated', { userId: req.user.id });

    res.json({ user: serializeUser(updated) });
  } catch (error) {
    logError('usersRouter', 'Failed to upload avatar', error);
    next(error);
  }
});

usersRouter.get('/', async (req, res, next) => {
  try {
    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
      },
    });
    res.json({ users });
  } catch (error) {
    logError('usersRouter', 'Failed to list users', error);
    next(error);
  }
});

usersRouter.post('/', async (req, res, next) => {
  try {
    return res.status(501).json({
      error: {
        code: 'not_implemented',
        message: 'Utilise /auth/register pour créer un utilisateur',
      },
    });
  } catch (error) {
    logError('usersRouter', 'Failed to create user', error);
    next(error);
  }
});
