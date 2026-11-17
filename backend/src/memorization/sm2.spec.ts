import { applySm2, MIN_EASE_FACTOR } from './sm2';

const DAY = 24 * 60 * 60 * 1000;
const now = new Date('2026-01-01T00:00:00.000Z');
const fresh = { repetitions: 0, easeFactor: 2.5, intervalDays: 0 };

describe('applySm2', () => {
  it('first successful review: interval 1, repetitions 1, REVIEWING', () => {
    const r = applySm2(fresh, 4, now);
    expect(r.repetitions).toBe(1);
    expect(r.intervalDays).toBe(1);
    expect(r.easeFactor).toBeCloseTo(2.5, 5); // q=4 leaves EF unchanged
    expect(r.status).toBe('REVIEWING');
    expect(r.nextReviewAt.getTime()).toBe(now.getTime() + DAY);
    expect(r.lastReviewedAt).toBe(now);
  });

  it('second successful review: interval 6', () => {
    const r = applySm2({ repetitions: 1, easeFactor: 2.5, intervalDays: 1 }, 5, now);
    expect(r.repetitions).toBe(2);
    expect(r.intervalDays).toBe(6);
    expect(r.easeFactor).toBeCloseTo(2.6, 5);
    expect(r.status).toBe('REVIEWING');
  });

  it('third+ review multiplies previous interval by EF', () => {
    const r = applySm2({ repetitions: 2, easeFactor: 2.5, intervalDays: 6 }, 4, now);
    expect(r.intervalDays).toBe(15);
    expect(r.repetitions).toBe(3);
    expect(r.status).toBe('REVIEWING');
  });

  it('becomes MEMORIZED once interval >= 21 days', () => {
    const r = applySm2({ repetitions: 3, easeFactor: 2.5, intervalDays: 15 }, 4, now);
    expect(r.intervalDays).toBe(38);
    expect(r.status).toBe('MEMORIZED');
  });

  it('failed recall (q<3) resets repetitions, interval 1 and LEARNING', () => {
    const r = applySm2({ repetitions: 5, easeFactor: 2.5, intervalDays: 40 }, 2, now);
    expect(r.repetitions).toBe(0);
    expect(r.intervalDays).toBe(1);
    expect(r.status).toBe('LEARNING');
    expect(r.easeFactor).toBeCloseTo(2.18, 5);
  });

  it('ease factor never drops below 1.3', () => {
    let state = { repetitions: 0, easeFactor: 1.4, intervalDays: 0 };
    for (let i = 0; i < 5; i++) {
      const r = applySm2(state, 0, now);
      state = r;
      expect(r.easeFactor).toBeGreaterThanOrEqual(MIN_EASE_FACTOR);
    }
    expect(state.easeFactor).toBe(MIN_EASE_FACTOR);
  });

  it('rejects invalid quality', () => {
    expect(() => applySm2(fresh, 6, now)).toThrow(RangeError);
    expect(() => applySm2(fresh, -1, now)).toThrow(RangeError);
    expect(() => applySm2(fresh, 2.5, now)).toThrow(RangeError);
  });
});
