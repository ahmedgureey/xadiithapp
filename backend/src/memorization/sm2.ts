import type { MemorizationStatus } from '@prisma/client';

export const MIN_EASE_FACTOR = 1.3;
export const DEFAULT_EASE_FACTOR = 2.5;
export const MEMORIZED_INTERVAL_DAYS = 21;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface Sm2State {
  repetitions: number;
  easeFactor: number;
  intervalDays: number;
}

export interface Sm2Result extends Sm2State {
  status: MemorizationStatus;
  nextReviewAt: Date;
  lastReviewedAt: Date;
}

/**
 * SuperMemo-2 scheduling.
 * quality: 0..5 (0-2 = failed recall, 3 = hard, 4 = good, 5 = easy)
 *
 * - quality < 3: repetitions reset to 0, interval 1 day, status LEARNING
 * - quality >= 3: interval 1 (first), 6 (second), then round(prevInterval * EF)
 * - EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)), never below 1.3
 * - status: intervalDays >= 21 -> MEMORIZED, else repetitions >= 1 -> REVIEWING
 */
export function applySm2(state: Sm2State, quality: number, now: Date = new Date()): Sm2Result {
  if (!Number.isInteger(quality) || quality < 0 || quality > 5) {
    throw new RangeError('quality must be an integer between 0 and 5');
  }
  const prevEf = Number.isFinite(state.easeFactor) ? state.easeFactor : DEFAULT_EASE_FACTOR;
  let repetitions = Math.max(0, state.repetitions | 0);
  let intervalDays: number;

  if (quality < 3) {
    repetitions = 0;
    intervalDays = 1;
  } else {
    if (repetitions === 0) intervalDays = 1;
    else if (repetitions === 1) intervalDays = 6;
    else intervalDays = Math.max(1, Math.round(Math.max(1, state.intervalDays) * prevEf));
    repetitions += 1;
  }

  const q = 5 - quality;
  let easeFactor = prevEf + (0.1 - q * (0.08 + q * 0.02));
  if (easeFactor < MIN_EASE_FACTOR) easeFactor = MIN_EASE_FACTOR;
  easeFactor = Math.round(easeFactor * 1000) / 1000;

  let status: MemorizationStatus;
  if (quality < 3) status = 'LEARNING';
  else if (intervalDays >= MEMORIZED_INTERVAL_DAYS) status = 'MEMORIZED';
  else status = 'REVIEWING';

  return {
    repetitions,
    easeFactor,
    intervalDays,
    status,
    lastReviewedAt: now,
    nextReviewAt: new Date(now.getTime() + intervalDays * DAY_MS),
  };
}
