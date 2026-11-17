import { Prisma } from '@prisma/client';

export const bookSummarySelect = {
  id: true,
  slug: true,
  nameArabic: true,
  nameSomali: true,
  nameEnglish: true,
} satisfies Prisma.HadithBookSelect;

/** Include used for every public Hadith response: only PUBLISHED translations/explanations. */
export const publicHadithInclude = {
  book: { select: bookSummarySelect },
  chapter: {
    select: { id: true, number: true, titleArabic: true, titleSomali: true, titleEnglish: true },
  },
  translations: {
    where: { status: 'PUBLISHED' },
    orderBy: [{ language: 'asc' }, { createdAt: 'asc' }],
  },
  gradings: { orderBy: { createdAt: 'asc' } },
  explanations: {
    where: { status: 'PUBLISHED' },
    orderBy: [{ language: 'asc' }, { createdAt: 'asc' }],
  },
  categories: {
    include: { category: true },
    orderBy: { category: { sortOrder: 'asc' } },
  },
} satisfies Prisma.HadithInclude;

/** Include used by admin endpoints: every translation/explanation regardless of status. */
export const adminHadithInclude = {
  ...publicHadithInclude,
  translations: { orderBy: [{ language: 'asc' }, { createdAt: 'asc' }] },
  explanations: { orderBy: [{ language: 'asc' }, { createdAt: 'asc' }] },
} satisfies Prisma.HadithInclude;

export type PublicHadithRecord = Prisma.HadithGetPayload<{ include: typeof publicHadithInclude }>;
export type AdminHadithRecord = Prisma.HadithGetPayload<{ include: typeof adminHadithInclude }>;

/** Natural order: book sort order, then numeric hadith number, then raw number ("52" < "52a"). */
export const hadithOrderBy: Prisma.HadithOrderByWithRelationInput[] = [
  { book: { sortOrder: 'asc' } },
  { hadithNumberSort: 'asc' },
  { hadithNumber: 'asc' },
];

export interface HadithDto {
  id: string;
  hadithNumber: string;
  arabicText: string;
  narrator: string | null;
  sourceReference: string | null;
  book: { id: string; slug: string; nameArabic: string; nameSomali: string; nameEnglish: string };
  chapter: {
    id: string;
    number: number;
    titleArabic: string | null;
    titleSomali: string | null;
    titleEnglish: string | null;
  } | null;
  translations: {
    id: string;
    language: string;
    text: string;
    translator: string | null;
    source: string | null;
  }[];
  gradings: { id: string; grade: string; gradedBy: string | null; source: string | null }[];
  explanations: {
    id: string;
    language: string;
    text: string;
    author: string | null;
    source: string | null;
  }[];
  categories: {
    id: string;
    slug: string;
    nameSomali: string;
    nameArabic: string;
    nameEnglish: string;
  }[];
  updatedAt: Date;
}

export function toHadithDto(h: PublicHadithRecord): HadithDto {
  return {
    id: h.id,
    hadithNumber: h.hadithNumber,
    arabicText: h.arabicText,
    narrator: h.narrator,
    sourceReference: h.sourceReference,
    book: {
      id: h.book.id,
      slug: h.book.slug,
      nameArabic: h.book.nameArabic,
      nameSomali: h.book.nameSomali,
      nameEnglish: h.book.nameEnglish,
    },
    chapter: h.chapter
      ? {
          id: h.chapter.id,
          number: h.chapter.number,
          titleArabic: h.chapter.titleArabic,
          titleSomali: h.chapter.titleSomali,
          titleEnglish: h.chapter.titleEnglish,
        }
      : null,
    translations: h.translations.map((t) => ({
      id: t.id,
      language: t.language,
      text: t.text,
      translator: t.translator,
      source: t.source,
    })),
    gradings: h.gradings.map((g) => ({
      id: g.id,
      grade: g.grade,
      gradedBy: g.gradedBy,
      source: g.source,
    })),
    explanations: h.explanations.map((e) => ({
      id: e.id,
      language: e.language,
      text: e.text,
      author: e.author,
      source: e.source,
    })),
    categories: h.categories.map(({ category: c }) => ({
      id: c.id,
      slug: c.slug,
      nameSomali: c.nameSomali,
      nameArabic: c.nameArabic,
      nameEnglish: c.nameEnglish,
    })),
    updatedAt: h.updatedAt,
  };
}

/** Admin representation: Hadith + status fields on the hadith and its translations/explanations. */
export function toAdminHadithDto(h: AdminHadithRecord) {
  const base = toHadithDto(h);
  return {
    ...base,
    status: h.status,
    publishedAt: h.publishedAt,
    createdAt: h.createdAt,
    translations: h.translations.map((t) => ({
      id: t.id,
      language: t.language,
      text: t.text,
      translator: t.translator,
      source: t.source,
      status: t.status,
    })),
    explanations: h.explanations.map((e) => ({
      id: e.id,
      language: e.language,
      text: e.text,
      author: e.author,
      source: e.source,
      status: e.status,
    })),
  };
}
