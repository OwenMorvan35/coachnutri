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

const genderValues = ['FEMALE', 'MALE', 'OTHER', 'UNSPECIFIED'];
const goalValues = ['LOSE', 'MAINTAIN', 'GAIN', 'UNSPECIFIED'];
const activityValues = ['SEDENTARY', 'LIGHT', 'MODERATE', 'ACTIVE', 'VERY_ACTIVE', 'UNSPECIFIED'];

const nutritionSchema = z.object({
  gender: z.enum(genderValues).optional(),
  birthDate: z
    .string()
    .datetime()
    .optional(),
  heightCm: z.number().min(80).max(260).optional(),
  startingWeightKg: z.number().min(20).max(400).optional(),
  goal: z.enum(goalValues).optional(),
  activityLevel: z.enum(activityValues).optional(),
  allergies: z.array(z.string().trim()).optional(),
  dietaryPreferences: z.array(z.string().trim()).optional(),
  constraints: z.array(z.string().trim()).optional(),
  budgetConstraint: z.string().trim().max(200).optional(),
  timeConstraint: z.string().trim().max(200).optional(),
  medicalConditions: z.string().trim().max(2000).optional(),
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

const serializeHealthProfile = (profile) => ({
  id: profile.id,
  userId: profile.userId,
  gender: profile.gender,
  birthDate: profile.birthDate,
  heightCm: profile.heightCm,
  startingWeightKg: profile.startingWeightKg,
  goal: profile.goal,
  activityLevel: profile.activityLevel,
  allergies: profile.allergies ?? [],
  dietaryPreferences: profile.dietaryPreferences ?? [],
  constraints: profile.constraints ?? [],
  budgetConstraint: profile.budgetConstraint,
  timeConstraint: profile.timeConstraint,
  medicalConditions: profile.medicalConditions,
  createdAt: profile.createdAt,
  updatedAt: profile.updatedAt,
});

const ensureHealthProfile = async (userId) => {
  return prisma.healthProfile.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });
};

const normalizeStringArray = (value) => {
  if (Array.isArray(value)) {
    return value
      .map((item) => (typeof item === 'string' ? item.trim() : String(item).trim()))
      .filter((item) => item.length > 0);
  }
  if (typeof value === 'string') {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }
  return [];
};

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

usersRouter.get('/me/nutrition', async (req, res, next) => {
  try {
    const profile = await ensureHealthProfile(req.user.id);
    res.json({ profile: serializeHealthProfile(profile) });
  } catch (error) {
    logError('usersRouter', 'Failed to fetch nutrition profile', error);
    next(error);
  }
});

usersRouter.put('/me/nutrition', async (req, res, next) => {
  try {
    const raw = req.body ?? {};
    const parsed = nutritionSchema.safeParse({
      gender: raw.gender,
      birthDate: raw.birthDate,
      heightCm: raw.heightCm != null ? Number(raw.heightCm) : undefined,
      startingWeightKg: raw.startingWeightKg != null ? Number(raw.startingWeightKg) : undefined,
      goal: raw.goal,
      activityLevel: raw.activityLevel,
      allergies: normalizeStringArray(raw.allergies),
      dietaryPreferences: normalizeStringArray(raw.dietaryPreferences),
      constraints: normalizeStringArray(raw.constraints),
      budgetConstraint: typeof raw.budgetConstraint === 'string' ? raw.budgetConstraint.trim() : undefined,
      timeConstraint: typeof raw.timeConstraint === 'string' ? raw.timeConstraint.trim() : undefined,
      medicalConditions: typeof raw.medicalConditions === 'string' ? raw.medicalConditions.trim() : undefined,
    });

    if (!parsed.success) {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: parsed.error.errors[0]?.message ?? 'Requête invalide',
        },
      });
    }

    const data = parsed.data;
    const birthDate = data.birthDate ? new Date(data.birthDate) : null;

    const profile = await prisma.healthProfile.upsert({
      where: { userId: req.user.id },
      update: {
        gender: data.gender ?? 'UNSPECIFIED',
        birthDate,
        heightCm: data.heightCm ?? null,
        startingWeightKg: data.startingWeightKg ?? null,
        goal: data.goal ?? 'UNSPECIFIED',
        activityLevel: data.activityLevel ?? 'UNSPECIFIED',
        allergies: data.allergies ?? [],
        dietaryPreferences: data.dietaryPreferences ?? [],
        constraints: data.constraints ?? [],
        budgetConstraint: data.budgetConstraint ?? null,
        timeConstraint: data.timeConstraint ?? null,
        medicalConditions: data.medicalConditions ?? null,
      },
      create: {
        userId: req.user.id,
        gender: data.gender ?? 'UNSPECIFIED',
        birthDate,
        heightCm: data.heightCm ?? null,
        startingWeightKg: data.startingWeightKg ?? null,
        goal: data.goal ?? 'UNSPECIFIED',
        activityLevel: data.activityLevel ?? 'UNSPECIFIED',
        allergies: data.allergies ?? [],
        dietaryPreferences: data.dietaryPreferences ?? [],
        constraints: data.constraints ?? [],
        budgetConstraint: data.budgetConstraint ?? null,
        timeConstraint: data.timeConstraint ?? null,
        medicalConditions: data.medicalConditions ?? null,
      },
    });

    logInfo('usersRouter', 'Nutrition profile updated', { userId: req.user.id });

    res.json({ profile: serializeHealthProfile(profile) });
  } catch (error) {
    logError('usersRouter', 'Failed to update nutrition profile', error);
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
