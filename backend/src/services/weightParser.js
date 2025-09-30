import { logError } from '../logger.js';

export class WeightValidationError extends Error {
  constructor(message, code = 'invalid_weight_request') {
    super(message);
    this.name = 'WeightValidationError';
    this.code = code;
  }
}

export const MIN_WEIGHT_KG = 20;
export const MAX_WEIGHT_KG = 400;

const MONTHS_FR = {
  janvier: 0,
  fevrier: 1,
  'février': 1,
  mars: 2,
  avril: 3,
  mai: 4,
  juin: 5,
  juillet: 6,
  aout: 7,
  'août': 7,
  septembre: 8,
  oct: 9,
  octobre: 9,
  nov: 10,
  novembre: 10,
  dec: 11,
  'décembre': 11,
  decembre: 11,
};

const MONTHS_FR_SHORT = {
  jan: 0,
  fev: 1,
  mar: 2,
  avr: 3,
  mai: 4,
  jun: 5,
  jul: 6,
  jui: 6,
  ao: 7,
  aou: 7,
  sep: 8,
  sept: 8,
  oct: 9,
  nov: 10,
  dec: 11,
};

const removeAccents = (value) =>
  value
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace('œ', 'oe')
    .replace('æ', 'ae');

const roundTo = (value, precision = 2) => {
  const factor = 10 ** precision;
  return Math.round(value * factor) / factor;
};

export const parseWeightValue = (input) => {
  const raw = typeof input === 'number' ? input : typeof input === 'string' ? input.trim() : null;

  if (raw === null || raw === '') {
    throw new WeightValidationError('Le poids est requis.', 'weight_required');
  }

  const numeric = typeof raw === 'number' ? raw : Number.parseFloat(raw.replace(',', '.'));
  if (Number.isNaN(numeric)) {
    throw new WeightValidationError('Le poids doit être un nombre valide.', 'weight_invalid');
  }

  if (numeric < MIN_WEIGHT_KG || numeric > MAX_WEIGHT_KG) {
    throw new WeightValidationError(
      `Le poids doit être compris entre ${MIN_WEIGHT_KG} et ${MAX_WEIGHT_KG} kg.`,
      'weight_out_of_range'
    );
  }

  return roundTo(numeric, 2);
};

export const parseDateInput = (input, { now = new Date() } = {}) => {
  if (!input) {
    return new Date(now);
  }

  let parsed;
  if (input instanceof Date) {
    parsed = new Date(input.getTime());
  } else if (typeof input === 'string') {
    const normalized = input.trim();
    if (!normalized) {
      throw new WeightValidationError('La date est invalide.', 'date_invalid');
    }
    parsed = new Date(normalized);
  } else if (typeof input === 'number') {
    parsed = new Date(input);
  } else {
    throw new WeightValidationError('La date est invalide.', 'date_invalid');
  }

  if (Number.isNaN(parsed.getTime())) {
    throw new WeightValidationError('La date est invalide.', 'date_invalid');
  }

  if (parsed.getTime() > now.getTime() + 500) {
    throw new WeightValidationError('La date ne peut pas être dans le futur.', 'date_future');
  }

  return parsed;
};

export const startOfDayUtc = (date) =>
  new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));

const addDaysUtc = (date, days) => {
  const result = new Date(date.getTime());
  result.setUTCDate(result.getUTCDate() + days);
  return result;
};

export const getRangeBounds = (range = 'week', { now = new Date() } = {}) => {
  const normalizedRange = typeof range === 'string' ? range.toLowerCase() : 'week';
  const end = new Date(now.getTime());
  const startOfToday = startOfDayUtc(now);

  switch (normalizedRange) {
    case 'day':
    case 'jour':
      return { start: startOfToday, end };
    case 'year':
    case 'annee': {
      const start = addDaysUtc(startOfToday, -364);
      return { start, end };
    }
    case 'month':
    case 'mois': {
      const start = addDaysUtc(startOfToday, -29);
      return { start, end };
    }
    case 'week':
    case 'semaine':
    default: {
      const start = addDaysUtc(startOfToday, -6);
      return { start, end };
    }
  }
};

const dayKeyUtc = (date) => {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export const aggregateEntries = (entries, mode = 'latest') => {
  if (!Array.isArray(entries) || entries.length === 0) {
    return [];
  }
  const sorted = entries
    .map((entry) => ({
      ...entry,
      date: new Date(entry.date),
      createdAt: entry.createdAt ? new Date(entry.createdAt) : new Date(entry.date),
      updatedAt: entry.updatedAt ? new Date(entry.updatedAt) : new Date(entry.date),
    }))
    .sort((a, b) => a.date.getTime() - b.date.getTime());

  if (mode === 'avg') {
    const byDay = new Map();
    for (const entry of sorted) {
      const key = dayKeyUtc(entry.date);
      if (!byDay.has(key)) {
        byDay.set(key, []);
      }
      byDay.get(key).push(entry);
    }

    const aggregate = [];
    for (const [key, bucket] of byDay) {
      const sum = bucket.reduce((acc, item) => acc + item.weightKg, 0);
      const avg = sum / bucket.length;
      const dayDate = startOfDayUtc(bucket[0].date);
      aggregate.push({
        id: `avg-${key}`,
        date: dayDate.toISOString(),
        weightKg: roundTo(avg, 2),
        note: null,
        source: null,
        createdAt: dayDate.toISOString(),
        updatedAt: dayDate.toISOString(),
        aggregated: { mode: 'avg', sampleSize: bucket.length },
      });
    }
    return aggregate.sort((a, b) => new Date(a.date) - new Date(b.date));
  }

  const latestByDay = new Map();
  for (const entry of sorted) {
    const key = dayKeyUtc(entry.date);
    const current = latestByDay.get(key);
    if (!current || entry.date.getTime() >= current.date.getTime()) {
      latestByDay.set(key, entry);
    }
  }

  return Array.from(latestByDay.values())
    .map((entry) => ({
      id: entry.id,
      date: entry.date.toISOString(),
      weightKg: roundTo(entry.weightKg, 2),
      note: entry.note ?? null,
      source: entry.source ?? null,
      createdAt: entry.createdAt.toISOString(),
      updatedAt: entry.updatedAt.toISOString(),
      aggregated: null,
    }))
    .sort((a, b) => new Date(a.date) - new Date(b.date));
};

export const computeStats = (entries) => {
  if (!Array.isArray(entries) || entries.length === 0) {
    return {
      latest: null,
      min: null,
      max: null,
      average: null,
    };
  }

  const weights = entries.map((entry) => entry.weightKg);
  const latestWeight = entries[entries.length - 1]?.weightKg ?? null;
  const minWeight = Math.min(...weights);
  const maxWeight = Math.max(...weights);
  const averageWeight = weights.reduce((acc, value) => acc + value, 0) / weights.length;

  return {
    latest: roundTo(latestWeight, 2),
    min: roundTo(minWeight, 2),
    max: roundTo(maxWeight, 2),
    average: roundTo(averageWeight, 2),
  };
};

const isValidDate = (date, expectedDay, expectedMonth) => {
  return (
    date.getUTCDate() === expectedDay &&
    date.getUTCMonth() === expectedMonth - 1
  );
};

const parseNumericDate = (text, now) => {
  const numericRegex = /(\b\d{1,2})[\/-](\d{1,2})(?:[\/-](\d{2,4}))?/;
  const match = numericRegex.exec(text);
  if (!match) return null;
  const day = Number.parseInt(match[1], 10);
  const month = Number.parseInt(match[2], 10);
  if (Number.isNaN(day) || Number.isNaN(month) || day < 1 || month < 1 || month > 12 || day > 31) {
    return null;
  }
  let year = match[3] ? Number.parseInt(match[3], 10) : now.getUTCFullYear();
  if (!match[3]) {
    let candidate = new Date(Date.UTC(year, month - 1, day));
    if (!isValidDate(candidate, day, month)) {
      return null;
    }
    if (candidate.getTime() > now.getTime()) {
      candidate = new Date(Date.UTC(year - 1, month - 1, day));
    }
    return candidate;
  }
  if (year < 100) {
    year += year >= 70 ? 1900 : 2000;
  }
  const candidate = new Date(Date.UTC(year, month - 1, day));
  if (!isValidDate(candidate, day, month)) {
    return null;
  }
  return candidate;
};

const parseTextualDate = (text, now) => {
  const monthRegex = /(\b\d{1,2})\s+([a-zéûàèùôîïç]{3,})/g;
  const matches = Array.from(text.matchAll(monthRegex));
  if (matches.length === 0) {
    return null;
  }
  const match = matches[matches.length - 1];
  if (!match) return null;
  const day = Number.parseInt(match[1], 10);
  if (Number.isNaN(day) || day < 1 || day > 31) {
    return null;
  }
  const monthToken = match[2];
  const monthNormalized = removeAccents(monthToken.toLowerCase());
  let monthIndex = MONTHS_FR[monthToken.toLowerCase()];
  if (typeof monthIndex !== 'number') {
    monthIndex = MONTHS_FR[monthNormalized];
  }
  if (typeof monthIndex !== 'number') {
    monthIndex = MONTHS_FR_SHORT[monthNormalized?.slice(0, 3) ?? ''];
  }
  if (typeof monthIndex !== 'number') {
    return null;
  }
  const trailing = text.slice(match.index + match[0].length).trim();
  const yearMatch = /^(\d{2,4})/.exec(trailing);
  let year = now.getUTCFullYear();
  if (yearMatch && yearMatch[1]) {
    year = Number.parseInt(yearMatch[1], 10);
    if (year < 100) {
      year += year >= 70 ? 1900 : 2000;
    }
  }

  let candidate = new Date(Date.UTC(year, monthIndex, day));
  if (!isValidDate(candidate, day, monthIndex + 1)) {
    return null;
  }
  if (!yearMatch && candidate.getTime() > now.getTime()) {
    candidate = new Date(Date.UTC(year - 1, monthIndex, day));
  }
  return candidate;
};

const parseRelativeDate = (text, now) => {
  const normalized = text.replace(/'/g, '');
  if (/\baujourdhui\b/.test(normalized)) {
    return startOfDayUtc(now);
  }
  if (/\bavant\s*h?ier\b/.test(normalized)) {
    return startOfDayUtc(addDaysUtc(now, -2));
  }
  if (/\bhier\b/.test(normalized)) {
    return startOfDayUtc(addDaysUtc(now, -1));
  }
  if (/\bdemain\b/.test(normalized) || /\bapres[-\s]?demain\b/.test(normalized)) {
    throw new WeightValidationError('La date ne peut pas être dans le futur.', 'date_future');
  }
  return null;
};

export const parseWeightCommand = (text, { now = new Date() } = {}) => {
  if (typeof text !== 'string' || !text.trim()) {
    throw new WeightValidationError('Texte vide, impossible de détecter un poids.', 'text_empty');
  }

  const weightRegex = /(\d{2,3}(?:[\.,]\d{1,2})?)\s*(kg|kilogrammes?|kilos?|kilograms?)/i;
  const weightMatch = weightRegex.exec(text);
  if (!weightMatch) {
    throw new WeightValidationError('Aucun poids détecté dans la phrase.', 'weight_missing');
  }

  const weightValue = parseWeightValue(weightMatch[1]);

  const lowercase = removeAccents(text.toLowerCase());

  let date = parseRelativeDate(lowercase, now);
  if (!date) {
    date = parseNumericDate(lowercase, now) || parseTextualDate(lowercase, now);
  }
  if (!date) {
    logError('weightParser', 'Failed to detect date in NLP text', { text });
    throw new WeightValidationError('Impossible de détecter la date de la mesure.', 'date_missing');
  }

  if (date.getTime() > now.getTime() + 500) {
    throw new WeightValidationError('La date ne peut pas être dans le futur.', 'date_future');
  }

  return {
    weightKg: weightValue,
    date,
  };
};
