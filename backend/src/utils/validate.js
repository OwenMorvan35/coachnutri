import { z } from 'zod';

const MessageSchema = z.object({
  role: z.enum(['user', 'coach']),
  content: z.string().min(1, 'Le contenu ne peut pas être vide'),
});

const ProfileSchema = z.object({
  age: z
    .number({ invalid_type_error: 'Age doit être un nombre' })
    .min(5, 'Age trop faible')
    .max(100, 'Age trop élevé')
    .optional(),
  heightCm: z
    .number({ invalid_type_error: 'La taille doit être un nombre' })
    .min(100, 'Taille trop faible')
    .max(230, 'Taille trop élevée')
    .optional(),
  weightKg: z
    .number({ invalid_type_error: 'Le poids doit être un nombre' })
    .min(30, 'Poids trop faible')
    .max(300, 'Poids trop élevé')
    .optional(),
  objective: z
    .enum(['perte de poids', 'maintien', 'prise de masse', 'mieux manger'])
    .optional(),
  prefs: z
    .array(z.string().min(1, 'Préférence vide interdite'), {
      invalid_type_error: 'prefs doit être une liste de chaînes',
    })
    .optional(),
});

const CoachRequestSchema = z.object({
  message: z.string().min(1, 'Le message principal ne peut pas être vide'),
  profile: ProfileSchema.optional(),
  history: z
    .array(MessageSchema, {
      invalid_type_error: 'history doit être une liste de messages',
    })
    .optional(),
});

export const validateCoachRequest = (body) => {
  const result = CoachRequestSchema.safeParse(body);
  if (!result.success) {
    return {
      data: null,
      error: result.error.flatten(),
    };
  }
  return {
    data: result.data,
    error: null,
  };
};

export { CoachRequestSchema, ProfileSchema, MessageSchema };
