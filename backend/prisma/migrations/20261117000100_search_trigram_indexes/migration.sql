-- Trigram search support.
-- Prisma `contains` + `mode: 'insensitive'` compiles to ILIKE '%q%', which can use
-- GIN trigram indexes. arabic_text_normalized holds diacritics-stripped Arabic
-- (maintained by the application) for tashkeel-insensitive matching.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS "hadiths_arabic_text_trgm_idx"
  ON "hadiths" USING GIN ("arabic_text" gin_trgm_ops);

CREATE INDEX IF NOT EXISTS "hadiths_arabic_text_normalized_trgm_idx"
  ON "hadiths" USING GIN ("arabic_text_normalized" gin_trgm_ops);

CREATE INDEX IF NOT EXISTS "hadiths_narrator_trgm_idx"
  ON "hadiths" USING GIN ("narrator" gin_trgm_ops);

CREATE INDEX IF NOT EXISTS "hadith_translations_text_trgm_idx"
  ON "hadith_translations" USING GIN ("text" gin_trgm_ops);
