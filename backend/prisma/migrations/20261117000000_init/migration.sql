-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('USER', 'EDITOR', 'REVIEWER', 'ADMIN');

-- CreateEnum
CREATE TYPE "hadith_status" AS ENUM ('DRAFT', 'PENDING_REVIEW', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "content_status" AS ENUM ('DRAFT', 'PENDING_REVIEW', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "memorization_status" AS ENUM ('NEW', 'LEARNING', 'REVIEWING', 'MEMORIZED');

-- CreateEnum
CREATE TYPE "review_status" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateTable
CREATE TABLE "hadith_books" (
    "id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "name_arabic" TEXT NOT NULL,
    "name_somali" TEXT NOT NULL,
    "name_english" TEXT NOT NULL,
    "author_name" TEXT NOT NULL,
    "description_somali" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "hadith_books_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "hadith_chapters" (
    "id" UUID NOT NULL,
    "book_id" UUID NOT NULL,
    "number" INTEGER NOT NULL,
    "title_arabic" TEXT,
    "title_somali" TEXT,
    "title_english" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "hadith_chapters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "hadiths" (
    "id" UUID NOT NULL,
    "book_id" UUID NOT NULL,
    "chapter_id" UUID,
    "hadith_number" TEXT NOT NULL,
    "hadith_number_sort" INTEGER NOT NULL DEFAULT 0,
    "arabic_text" TEXT NOT NULL,
    "arabic_text_normalized" TEXT NOT NULL DEFAULT '',
    "narrator" TEXT,
    "source_reference" TEXT,
    "status" "hadith_status" NOT NULL DEFAULT 'DRAFT',
    "published_at" TIMESTAMPTZ(3),
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "hadiths_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "hadith_translations" (
    "id" UUID NOT NULL,
    "hadith_id" UUID NOT NULL,
    "language" VARCHAR(10) NOT NULL,
    "text" TEXT NOT NULL,
    "translator" TEXT,
    "source" TEXT,
    "status" "content_status" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "hadith_translations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "hadith_gradings" (
    "id" UUID NOT NULL,
    "hadith_id" UUID NOT NULL,
    "grade" TEXT NOT NULL,
    "graded_by" TEXT,
    "source" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "hadith_gradings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "hadith_explanations" (
    "id" UUID NOT NULL,
    "hadith_id" UUID NOT NULL,
    "language" VARCHAR(10) NOT NULL,
    "text" TEXT NOT NULL,
    "author" TEXT,
    "source" TEXT,
    "status" "content_status" NOT NULL DEFAULT 'DRAFT',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "hadith_explanations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "name_somali" TEXT NOT NULL,
    "name_arabic" TEXT NOT NULL,
    "name_english" TEXT NOT NULL,
    "icon" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "hadith_categories" (
    "hadith_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "hadith_categories_pkey" PRIMARY KEY ("hadith_id","category_id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "user_role" NOT NULL DEFAULT 'USER',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profiles" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "display_name" VARCHAR(80) NOT NULL,
    "preferred_language" VARCHAR(5) NOT NULL DEFAULT 'so',
    "theme" VARCHAR(20) NOT NULL DEFAULT 'system',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "family_id" UUID NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "replaced_by" UUID,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bookmarks" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "hadith_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "bookmarks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "memorization_progress" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "hadith_id" UUID NOT NULL,
    "status" "memorization_status" NOT NULL DEFAULT 'NEW',
    "repetitions" INTEGER NOT NULL DEFAULT 0,
    "ease_factor" DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    "interval_days" INTEGER NOT NULL DEFAULT 0,
    "next_review_at" TIMESTAMPTZ(3),
    "last_reviewed_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "memorization_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reading_history" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "hadith_id" UUID NOT NULL,
    "viewed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "reading_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_notification_settings" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "daily_hadith" BOOLEAN NOT NULL DEFAULT true,
    "review_reminders" BOOLEAN NOT NULL DEFAULT true,
    "reminder_time" VARCHAR(5) NOT NULL DEFAULT '08:00',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "user_notification_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "content_reviews" (
    "id" UUID NOT NULL,
    "entity_type" VARCHAR(40) NOT NULL,
    "entity_id" UUID NOT NULL,
    "status" "review_status" NOT NULL DEFAULT 'PENDING',
    "submitted_by" UUID NOT NULL,
    "reviewed_by" UUID,
    "notes" TEXT,
    "reviewed_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "content_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "content_change_history" (
    "id" UUID NOT NULL,
    "entity_type" VARCHAR(40) NOT NULL,
    "entity_id" UUID NOT NULL,
    "action" VARCHAR(40) NOT NULL,
    "changed_by" UUID,
    "before" JSONB,
    "after" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "content_change_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "admin_roles" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "user_role" NOT NULL,
    "scope" VARCHAR(80),
    "granted_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "admin_roles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "hadith_books_slug_key" ON "hadith_books"("slug");

-- CreateIndex
CREATE INDEX "hadith_books_sort_order_idx" ON "hadith_books"("sort_order");

-- CreateIndex
CREATE INDEX "hadith_chapters_book_id_idx" ON "hadith_chapters"("book_id");

-- CreateIndex
CREATE UNIQUE INDEX "hadith_chapters_book_id_number_key" ON "hadith_chapters"("book_id", "number");

-- CreateIndex
CREATE INDEX "hadiths_book_id_idx" ON "hadiths"("book_id");

-- CreateIndex
CREATE INDEX "hadiths_chapter_id_idx" ON "hadiths"("chapter_id");

-- CreateIndex
CREATE INDEX "hadiths_status_idx" ON "hadiths"("status");

-- CreateIndex
CREATE INDEX "hadiths_hadith_number_idx" ON "hadiths"("hadith_number");

-- CreateIndex
CREATE INDEX "hadiths_book_id_hadith_number_sort_idx" ON "hadiths"("book_id", "hadith_number_sort");

-- CreateIndex
CREATE UNIQUE INDEX "hadiths_book_id_hadith_number_key" ON "hadiths"("book_id", "hadith_number");

-- CreateIndex
CREATE INDEX "hadith_translations_hadith_id_idx" ON "hadith_translations"("hadith_id");

-- CreateIndex
CREATE INDEX "hadith_translations_language_status_idx" ON "hadith_translations"("language", "status");

-- CreateIndex
CREATE INDEX "hadith_gradings_hadith_id_idx" ON "hadith_gradings"("hadith_id");

-- CreateIndex
CREATE INDEX "hadith_explanations_hadith_id_idx" ON "hadith_explanations"("hadith_id");

-- CreateIndex
CREATE INDEX "hadith_explanations_language_status_idx" ON "hadith_explanations"("language", "status");

-- CreateIndex
CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");

-- CreateIndex
CREATE INDEX "categories_sort_order_idx" ON "categories"("sort_order");

-- CreateIndex
CREATE INDEX "hadith_categories_category_id_idx" ON "hadith_categories"("category_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "profiles_user_id_key" ON "profiles"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_tokens_user_id_idx" ON "refresh_tokens"("user_id");

-- CreateIndex
CREATE INDEX "refresh_tokens_family_id_idx" ON "refresh_tokens"("family_id");

-- CreateIndex
CREATE INDEX "bookmarks_hadith_id_idx" ON "bookmarks"("hadith_id");

-- CreateIndex
CREATE UNIQUE INDEX "bookmarks_user_id_hadith_id_key" ON "bookmarks"("user_id", "hadith_id");

-- CreateIndex
CREATE INDEX "memorization_progress_user_id_status_idx" ON "memorization_progress"("user_id", "status");

-- CreateIndex
CREATE INDEX "memorization_progress_user_id_next_review_at_idx" ON "memorization_progress"("user_id", "next_review_at");

-- CreateIndex
CREATE INDEX "memorization_progress_hadith_id_idx" ON "memorization_progress"("hadith_id");

-- CreateIndex
CREATE UNIQUE INDEX "memorization_progress_user_id_hadith_id_key" ON "memorization_progress"("user_id", "hadith_id");

-- CreateIndex
CREATE INDEX "reading_history_user_id_viewed_at_idx" ON "reading_history"("user_id", "viewed_at");

-- CreateIndex
CREATE INDEX "reading_history_hadith_id_idx" ON "reading_history"("hadith_id");

-- CreateIndex
CREATE UNIQUE INDEX "reading_history_user_id_hadith_id_key" ON "reading_history"("user_id", "hadith_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_notification_settings_user_id_key" ON "user_notification_settings"("user_id");

-- CreateIndex
CREATE INDEX "content_reviews_status_idx" ON "content_reviews"("status");

-- CreateIndex
CREATE INDEX "content_reviews_entity_type_entity_id_idx" ON "content_reviews"("entity_type", "entity_id");

-- CreateIndex
CREATE INDEX "content_change_history_entity_type_entity_id_idx" ON "content_change_history"("entity_type", "entity_id");

-- CreateIndex
CREATE UNIQUE INDEX "admin_roles_user_id_role_scope_key" ON "admin_roles"("user_id", "role", "scope");

-- AddForeignKey
ALTER TABLE "hadith_chapters" ADD CONSTRAINT "hadith_chapters_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "hadith_books"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadiths" ADD CONSTRAINT "hadiths_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "hadith_books"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadiths" ADD CONSTRAINT "hadiths_chapter_id_fkey" FOREIGN KEY ("chapter_id") REFERENCES "hadith_chapters"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadiths" ADD CONSTRAINT "hadiths_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadith_translations" ADD CONSTRAINT "hadith_translations_hadith_id_fkey" FOREIGN KEY ("hadith_id") REFERENCES "hadiths"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadith_gradings" ADD CONSTRAINT "hadith_gradings_hadith_id_fkey" FOREIGN KEY ("hadith_id") REFERENCES "hadiths"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadith_explanations" ADD CONSTRAINT "hadith_explanations_hadith_id_fkey" FOREIGN KEY ("hadith_id") REFERENCES "hadiths"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadith_categories" ADD CONSTRAINT "hadith_categories_hadith_id_fkey" FOREIGN KEY ("hadith_id") REFERENCES "hadiths"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hadith_categories" ADD CONSTRAINT "hadith_categories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookmarks" ADD CONSTRAINT "bookmarks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookmarks" ADD CONSTRAINT "bookmarks_hadith_id_fkey" FOREIGN KEY ("hadith_id") REFERENCES "hadiths"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "memorization_progress" ADD CONSTRAINT "memorization_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "memorization_progress" ADD CONSTRAINT "memorization_progress_hadith_id_fkey" FOREIGN KEY ("hadith_id") REFERENCES "hadiths"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reading_history" ADD CONSTRAINT "reading_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reading_history" ADD CONSTRAINT "reading_history_hadith_id_fkey" FOREIGN KEY ("hadith_id") REFERENCES "hadiths"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_notification_settings" ADD CONSTRAINT "user_notification_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "content_reviews" ADD CONSTRAINT "content_reviews_submitted_by_fkey" FOREIGN KEY ("submitted_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "content_reviews" ADD CONSTRAINT "content_reviews_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "content_change_history" ADD CONSTRAINT "content_change_history_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "admin_roles" ADD CONSTRAINT "admin_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

