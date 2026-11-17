import { hadithNumberSortKey, isUuid, looksLikeHadithNumber } from '../utils/hadith-number';
import { DEFAULT_LIMIT, MAX_LIMIT, paginate, toPageParams } from './pagination';

describe('toPageParams', () => {
  it('applies defaults', () => {
    expect(toPageParams()).toEqual({ page: 1, limit: DEFAULT_LIMIT, skip: 0, take: DEFAULT_LIMIT });
    expect(toPageParams({})).toEqual({ page: 1, limit: 20, skip: 0, take: 20 });
  });

  it('computes skip/take', () => {
    expect(toPageParams({ page: 3, limit: 10 })).toEqual({ page: 3, limit: 10, skip: 20, take: 10 });
  });

  it('clamps limit to MAX_LIMIT and fixes invalid values', () => {
    expect(toPageParams({ limit: 500 }).limit).toBe(MAX_LIMIT);
    expect(toPageParams({ page: 0, limit: 0 })).toEqual({ page: 1, limit: 20, skip: 0, take: 20 });
    expect(toPageParams({ page: -4 }).page).toBe(1);
    expect(toPageParams({ page: NaN }).page).toBe(1);
    expect(toPageParams({ page: 2.7, limit: 9.9 })).toEqual({ page: 2, limit: 9, skip: 9, take: 9 });
  });
});

describe('paginate', () => {
  it('builds meta with totalPages', () => {
    const res = paginate([1, 2], 123, toPageParams({ page: 1, limit: 20 }));
    expect(res).toEqual({ data: [1, 2], meta: { page: 1, limit: 20, total: 123, totalPages: 7 } });
  });

  it('totalPages is 0 for empty results', () => {
    expect(paginate([], 0, toPageParams()).meta.totalPages).toBe(0);
  });

  it('exact multiple', () => {
    expect(paginate([], 40, toPageParams({ limit: 20 })).meta.totalPages).toBe(2);
  });
});

describe('hadith number helpers', () => {
  it('extracts a numeric sort key', () => {
    expect(hadithNumberSortKey('1')).toBe(1);
    expect(hadithNumberSortKey('52a')).toBe(52);
    expect(hadithNumberSortKey('abc')).toBe(0);
  });

  it('detects number-like queries', () => {
    expect(looksLikeHadithNumber('52')).toBe(true);
    expect(looksLikeHadithNumber(' 52a ')).toBe(true);
    expect(looksLikeHadithNumber('salaad')).toBe(false);
  });

  it('detects uuids', () => {
    expect(isUuid('6f1c2a4e-1b2c-4d5e-8f90-123456789abc')).toBe(true);
    expect(isUuid('sahih-bukhari')).toBe(false);
  });
});
