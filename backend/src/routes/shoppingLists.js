import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db/client.js';
import { logError, logInfo } from '../logger.js';
import { requireAuth } from '../middleware/auth.js';

export const shoppingListsRouter = Router();

shoppingListsRouter.use(requireAuth);

shoppingListsRouter.get('/', async (req, res, next) => {
  try {
    const lists = await prisma.shoppingList.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ lists });
  } catch (error) {
    logError('shoppingListsRouter', 'Failed to list shopping lists', error);
    next(error);
  }
});

shoppingListsRouter.post('/', async (req, res, next) => {
  try {
    const payload = req.body || {};
    if (!payload.title) {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: 'title est requis',
        },
      });
    }

    const list = await prisma.shoppingList.create({
      data: {
        userId: req.user.id,
        title: payload.title,
        items: Array.isArray(payload.items) ? payload.items : [],
      },
    });

    logInfo('shoppingListsRouter', 'Shopping list created', {
      shoppingListId: list.id,
      userId: req.user.id,
    });
    res.status(201).json({ list });
  } catch (error) {
    logError('shoppingListsRouter', 'Failed to create shopping list', error);
    next(error);
  }
});

const toKey = (s = '') => {
  if (!s) return '';
  const lower = s.toLowerCase();
  const map = {
    'à':'a','á':'a','â':'a','ä':'a','ã':'a','å':'a','æ':'ae',
    'ç':'c',
    'è':'e','é':'e','ê':'e','ë':'e',
    'ì':'i','í':'i','î':'i','ï':'i',
    'ñ':'n',
    'ò':'o','ó':'o','ô':'o','ö':'o','õ':'o','œ':'oe',
    'ù':'u','ú':'u','û':'u','ü':'u',
    'ý':'y','ÿ':'y',
  };
  const replaced = lower.split('').map((ch) => map[ch] || ch).join('');
  return replaced.replace(/[^a-z0-9]/g, '');
};

const resolveList = async (userId, listIdOrAlias = 'default') => {
  if (listIdOrAlias === 'default') {
    let list = await prisma.shoppingList.findFirst({ where: { userId, title: 'default' } });
    if (!list) {
      list = await prisma.shoppingList.create({ data: { userId, title: 'default', items: [] } });
    }
    return list;
  }
  const byId = await prisma.shoppingList.findFirst({ where: { id: listIdOrAlias, userId } });
  if (byId) return byId;
  // fallback: alias maps to title
  const byTitle = await prisma.shoppingList.findFirst({ where: { userId, title: listIdOrAlias } });
  if (byTitle) return byTitle;
  // if missing, create with given title
  return prisma.shoppingList.create({ data: { userId, title: listIdOrAlias, items: [] } });
};

// Fetch items of a list
shoppingListsRouter.get('/:listId/items', async (req, res, next) => {
  try {
    const list = await resolveList(req.user.id, req.params.listId || 'default');
    const items = await prisma.shoppingItem.findMany({
      where: { listId: list.id },
      orderBy: [{ isChecked: 'asc' }, { updatedAt: 'asc' }, { displayName: 'asc' }],
    });
    res.json({ list: { id: list.id, title: list.title }, items });
  } catch (error) {
    logError('shoppingListsRouter', 'Failed to list items', error);
    next(error);
  }
});

const ShoppingOpSchema = z.object({
  name: z.string().min(1),
  qty: z.number().optional(),
  unit: z.string().optional(),
  category: z.string().optional(),
  note: z.string().optional(),
  op: z.enum(['add', 'remove', 'toggle']),
});

shoppingListsRouter.post('/:listId/items/apply', async (req, res, next) => {
  try {
    const list = await resolveList(req.user.id, req.params.listId || 'default');
    const raw = Array.isArray(req.body?.items) ? req.body.items : [];
    const ops = raw
      .map((r) => ShoppingOpSchema.safeParse(r))
      .filter((p) => p.success)
      .map((p) => p.data);
    const results = [];
    for (const op of ops) {
      const key = toKey(op.name);
      if (!key) continue;
      if (op.op === 'add') {
        const existing = await prisma.shoppingItem.findUnique({ where: { listId_nameKey: { listId: list.id, nameKey: key } } }).catch(() => null);
        if (!existing) {
          const created = await prisma.shoppingItem.create({
            data: {
              listId: list.id,
              displayName: op.name,
              nameKey: key,
              qty: op.qty ?? null,
              unit: op.unit ?? null,
              category: op.category ?? 'autres',
              note: op.note ?? null,
            },
          });
          results.push(created);
        } else {
          // merge quantities if same unit else overwrite qty/unit; concat notes
          const nextQty = (existing.unit ?? '') === (op.unit ?? '')
            ? (existing.qty ?? 0) + (op.qty ?? 0)
            : (op.qty ?? existing.qty);
          const nextUnit = op.unit ?? existing.unit;
          const nextNote = op.note && op.note.length > 0
            ? (existing.note && existing.note.length > 0 ? `${existing.note} | ${op.note}` : op.note)
            : existing.note;
          const updated = await prisma.shoppingItem.update({
            where: { id: existing.id },
            data: {
              qty: nextQty,
              unit: nextUnit,
              note: nextNote,
              category: op.category ?? existing.category,
              updatedAt: new Date(),
            },
          });
          results.push(updated);
        }
      } else if (op.op === 'remove') {
        await prisma.shoppingItem.deleteMany({ where: { listId: list.id, nameKey: key } });
      } else if (op.op === 'toggle') {
        const existing = await prisma.shoppingItem.findUnique({ where: { listId_nameKey: { listId: list.id, nameKey: key } } }).catch(() => null);
        if (existing) {
          await prisma.shoppingItem.update({
            where: { id: existing.id },
            data: { isChecked: !existing.isChecked, updatedAt: new Date() },
          });
        }
      }
    }
    const items = await prisma.shoppingItem.findMany({
      where: { listId: list.id },
      orderBy: [{ isChecked: 'asc' }, { updatedAt: 'asc' }, { displayName: 'asc' }],
    });
    res.status(200).json({ list: { id: list.id, title: list.title }, items });
  } catch (error) {
    logError('shoppingListsRouter', 'Failed to apply shopping ops', error);
    next(error);
  }
});
