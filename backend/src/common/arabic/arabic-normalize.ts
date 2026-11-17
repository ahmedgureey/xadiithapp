/**
 * Arabic text normalisation for search.
 *
 * - removes tashkeel / harakat (U+064B-U+065F), superscript alef (U+0670),
 *   Quranic annotation marks (U+06D6-U+06ED) and tatweel (U+0640)
 * - unifies alef variants (أ إ آ ٱ) to bare alef (ا)
 * - alef maqsura (ى) -> ya (ي), ta marbuta (ة) -> ha (ه)
 * - hamza on waw/ya (ؤ ئ) -> و / ي
 * - collapses whitespace and trims
 *
 * The same function is applied to stored text (hadiths.arabic_text_normalized)
 * and to the user's query, so searches match regardless of diacritics.
 */
const DIACRITICS = /[ً-ٰٟۖ-ۭـ]/g;

export function normalizeArabic(input: string | null | undefined): string {
  if (!input) return '';
  return input
    .normalize('NFC')
    .replace(DIACRITICS, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/\s+/g, ' ')
    .trim();
}

export function containsArabic(input: string): boolean {
  return /[؀-ۿ]/.test(input);
}
