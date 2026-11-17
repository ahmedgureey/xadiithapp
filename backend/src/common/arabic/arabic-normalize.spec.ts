import { containsArabic, normalizeArabic } from './arabic-normalize';

describe('normalizeArabic', () => {
  it('strips tashkeel (harakat, shadda, sukun, tanween)', () => {
    // "kataba" with fatha on each letter -> bare letters
    expect(normalizeArabic('كَتَبَ')).toBe('كتب');
    // shadda + kasratan
    expect(normalizeArabic('مُحَمَّدٍ')).toBe(
      'محمد',
    );
  });

  it('removes tatweel and superscript alef', () => {
    expect(normalizeArabic('كــتب')).toBe('كتب');
    expect(normalizeArabic('هٰذا')).toBe('هذا');
  });

  it('unifies alef variants, alef maqsura, ta marbuta and hamza carriers', () => {
    expect(normalizeArabic('أإآٱ')).toBe('اااا');
    expect(normalizeArabic('على')).toBe('علي');
    expect(normalizeArabic('صلاة')).toBe('صلاه');
    expect(normalizeArabic('مؤمن')).toBe('مومن');
    expect(normalizeArabic('سئل')).toBe('سيل');
  });

  it('is idempotent and collapses whitespace', () => {
    const once = normalizeArabic('  إِنَّمَا   الأعمال  ');
    expect(once).toBe('انما الاعمال');
    expect(normalizeArabic(once)).toBe(once);
  });

  it('leaves Latin text untouched (except whitespace) and handles empty input', () => {
    expect(normalizeArabic('  Hello   World ')).toBe('Hello World');
    expect(normalizeArabic('')).toBe('');
    expect(normalizeArabic(null)).toBe('');
    expect(normalizeArabic(undefined)).toBe('');
  });

  it('detects Arabic script', () => {
    expect(containsArabic('كتب')).toBe(true);
    expect(containsArabic('Somali text')).toBe(false);
  });
});
