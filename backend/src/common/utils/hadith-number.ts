/** Extracts the leading integer of a hadith number for natural sorting ("52a" -> 52). */
export function hadithNumberSortKey(hadithNumber: string): number {
  const match = /\d+/.exec(hadithNumber ?? '');
  if (!match) return 0;
  const n = Number.parseInt(match[0], 10);
  return Number.isSafeInteger(n) && n <= 2_147_483_647 ? n : 0;
}

/** True when the query looks like a hadith number, e.g. "1", "52", "52a". */
export function looksLikeHadithNumber(q: string): boolean {
  return /^\d{1,6}[a-zA-Z]?$/.test(q.trim());
}

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}
