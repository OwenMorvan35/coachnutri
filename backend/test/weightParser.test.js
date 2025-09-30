import { test } from 'node:test';
import assert from 'node:assert';

const {
  parseWeightValue,
  parseWeightCommand,
  WeightValidationError,
  getRangeBounds,
} = await import('../src/services/weightParser.js');

const toIsoDate = (date) => date.toISOString().slice(0, 10);

test('parseWeightValue accepts comma separator', () => {
  const value = parseWeightValue('82,4');
  assert.strictEqual(value, 82.4);
});

test('parseWeightValue rejects out-of-range values', () => {
  assert.throws(() => parseWeightValue('12'), (error) => {
    assert(error instanceof WeightValidationError);
    return error.code === 'weight_out_of_range';
  });
});

test('parseWeightCommand extracts weight and explicit date', () => {
  const now = new Date('2025-09-15T08:00:00.000Z');
  const command = 'Peux-tu enregistrer 81,7 kg le 12/09/2025 ?';
  const { weightKg, date } = parseWeightCommand(command, { now });
  assert.strictEqual(weightKg, 81.7);
  assert.strictEqual(toIsoDate(date), '2025-09-12');
});

test('parseWeightCommand recognises textual French month', () => {
  const now = new Date('2025-09-20T08:00:00.000Z');
  const command = 'ajoute 80,2 kg le 12 septembre';
  const { weightKg, date } = parseWeightCommand(command, { now });
  assert.strictEqual(weightKg, 80.2);
  assert.strictEqual(toIsoDate(date), '2025-09-12');
});

test('parseWeightCommand handles relative terms "hier"', () => {
  const now = new Date('2025-09-15T08:00:00.000Z');
  const command = 'enregistre 83 kg hier';
  const { weightKg, date } = parseWeightCommand(command, { now });
  assert.strictEqual(weightKg, 83);
  assert.strictEqual(toIsoDate(date), '2025-09-14');
});

test('parseWeightCommand rejects future dates', () => {
  const now = new Date('2025-09-15T08:00:00.000Z');
  const command = 'note 84 kg demain';
  assert.throws(() => parseWeightCommand(command, { now }), (error) => {
    assert(error instanceof WeightValidationError);
    return error.code === 'date_future';
  });
});

test('getRangeBounds returns 7-day window for week', () => {
  const now = new Date('2025-09-20T10:00:00.000Z');
  const { start, end } = getRangeBounds('week', { now });
  assert.strictEqual(start.toISOString().slice(0, 10), '2025-09-14');
  assert.strictEqual(end.toISOString(), now.toISOString());
});

test('getRangeBounds returns 365-day window for year', () => {
  const now = new Date('2025-09-20T10:00:00.000Z');
  const { start, end } = getRangeBounds('year', { now });
  assert.strictEqual(start.toISOString().slice(0, 10), '2024-09-21');
  assert.strictEqual(end.toISOString(), now.toISOString());
});
