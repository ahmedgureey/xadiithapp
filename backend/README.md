# Xadiis App - Backend API

REST API for the Xadiis App (Somali Hadith reading and memorization).
Stack: **NestJS 11**, **Prisma 6** with **PostgreSQL**, class-validator, Swagger/OpenAPI, JWT access tokens + rotating opaque refresh tokens, argon2id, @nestjs/throttler, helmet.

- Base path: `/api/v1`
- OpenAPI UI: `/api/docs`, JSON: `/api/docs-json`
- Health: `GET /api/v1/health`

> **Content policy:** the seed contains **no hadith text, translations, gradings or explanations**. All religious content has to be entered through the admin review workflow, with a source reference and a sourced grading, before anything is published.

---

## Quick start (local)

Requirements: Node.js 22+ (tested on Node 26 / npm 11) and a PostgreSQL 14+ database. The `pg_trgm` extension is created by a migration. It is a trusted extension on PG 13+, so the database owner can create it.

```bash
cd backend
cp .env.example .env          # then edit DATABASE_URL and JWT_ACCESS_SECRET
npm install
npx prisma migrate deploy     # apply committed migrations
npm run db:seed               # books + categories (+ optional admin)
npm run start:dev             # http://localhost:3000/api/v1
```

Or use Docker Compose (Postgres + API, ports bound to 127.0.0.1 only):

```bash
# .env must define POSTGRES_PASSWORD and JWT_ACCESS_SECRET
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
docker compose exec api npm run seed:prod
```

## Scripts

| Script | What it does |
| --- | --- |
| `npm run build` | Compile the API to `dist/` and the seed to `dist-seed/` |
| `npm start` / `start:prod` | Run the compiled API (`node dist/main.js`) |
| `npm run start:dev` | Watch mode |
| `npm run lint` | ESLint (typescript-eslint, flat config) |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Unit tests (Jest): SM-2, Arabic normalization, pagination, auth service |
| `npm run test:e2e` | e2e tests (supertest) against a **real** Postgres. Needs `DATABASE_URL` |
| `npm run prisma:migrate:dev` | Create a new migration while developing (`prisma migrate dev --name <x>`) |
| `npm run prisma:migrate:deploy` | Apply migrations (production / CI) |
| `npm run db:seed` | Seed through ts-node (dev) |
| `npm run seed:prod` | Seed with the compiled JS (inside the Docker image) |

### Running e2e tests

The e2e suite **truncates** user and hadith tables. It refuses to run unless the database name contains `test`.

```bash
createdb xadiis_test
export DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:5432/xadiis_test"
npx prisma migrate deploy && npm run db:seed
npm run test:e2e
```

With a pooler such as PgBouncer, or with PGlite's socket server (single shared session), add `?pgbouncer=true&connection_limit=1` to the URL so Prisma doesn't reuse named prepared statements.

The test fixtures use obvious placeholder strings (`TEST ARABIC TEXT`, ...). They are created by the test itself and are never seeded.

## Environment variables

| Name | Required | Default | Notes |
| --- | --- | --- | --- |
| `DATABASE_URL` | yes | - | PostgreSQL connection string |
| `JWT_ACCESS_SECRET` | yes | - | at least 32 chars, `openssl rand -base64 48` |
| `JWT_ACCESS_TTL` | no | `900` | access-token lifetime (seconds) |
| `JWT_REFRESH_TTL_DAYS` | no | `30` | refresh-token lifetime (days) |
| `PORT` | no | `3000` | |
| `NODE_ENV` | no | `development` | `development`, `production` or `test` |
| `CORS_ORIGINS` | no | empty | comma list. Empty means CORS is disabled (mobile apps don't need it) |
| `TRUST_PROXY` | no | `false` | `true` behind Coolify/Traefik so rate limits use the real client IP |
| `THROTTLE_LIMIT` | no | `120` | requests/min/IP (general) |
| `AUTH_THROTTLE_LIMIT` | no | `5` | requests/min/IP on login/register/refresh |
| `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD` | no | - | create an ADMIN user when seeding (password at least 12 chars) |
| `RUN_MIGRATIONS` | no | `true` | Docker entrypoint runs `prisma migrate deploy` on start |

The app **fails fast** at startup if `DATABASE_URL` or `JWT_ACCESS_SECRET` is missing or invalid.

## API conventions

- Success: `{ "data": ... }`. Lists: `{ "data": [...], "meta": { "page", "limit", "total", "totalPages" } }`.
- Query `page` (default 1) and `limit` (default 20, max 100).
- Errors: `{ "statusCode", "error", "message" (string or string[]), "path", "timestamp" }`.
- Public endpoints return **only PUBLISHED hadiths**, and only translations/explanations whose status is PUBLISHED.

## Endpoints

Public:

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/health` | `{status, database, version, timestamp}`. 503 if the DB is down. Not throttled |
| GET | `/books` | sorted by `sortOrder` |
| GET | `/books/:id` | `:id` = UUID **or** slug (`sahih-bukhari`) |
| GET | `/books/:id/chapters` | sorted by `number` |
| GET | `/hadiths?bookId&chapterId&categoryId` | natural order: book sortOrder, then numeric hadith number |
| GET | `/hadiths/:id` | |
| GET | `/categories` | |
| GET | `/search?q&bookId&categoryId` | Arabic text (diacritics-insensitive), published Somali translation, narrator, book names, exact hadith number |
| GET | `/hadith-of-the-day` | deterministic per UTC date. `data: null` if nothing is published |

Auth (5 requests/min/IP on register/login/refresh):

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/register` | `{email, password(min 8), displayName(1-80)}`. 201 AuthResult, 409 if the email exists |
| POST | `/auth/login` | 200 AuthResult. 401 `Invalid email or password` |
| POST | `/auth/refresh` | `{refreshToken}`. Rotates the token. Reusing a revoked token revokes the whole family |
| POST | `/auth/logout` | `{refreshToken}`. Always 204 |

Authenticated (`Authorization: Bearer <accessToken>`):

| Method | Path | Notes |
| --- | --- | --- |
| GET / PATCH | `/me` | PATCH `{displayName?, preferredLanguage?: 'so' or 'en'}` |
| GET / PUT | `/me/notification-settings` | `{dailyHadith, reviewReminders, reminderTime: "HH:mm"}` |
| GET / POST | `/bookmarks` | POST `{hadithId}` is idempotent (201). 404 if the hadith is not published |
| DELETE | `/bookmarks/:hadithId` | **path param is the HADITH id, not the bookmark id**. Idempotent 204 |
| GET | `/memorization?status=&due=true` | |
| POST | `/memorization` | `{hadithId}`. Idempotent (201) |
| PATCH | `/memorization/:id` | `{quality: 0..5}` (SM-2) **or** `{status}`. Exactly one |
| DELETE | `/memorization/:id` | 204. Other users' records return 404 |
| GET / POST | `/reading-history` | POST `{hadithId}` upserts `viewedAt` (one row per hadith) |

Admin (role-guarded. ADMIN can do everything):

| Method | Path | Roles |
| --- | --- | --- |
| POST | `/admin/hadiths` | EDITOR, REVIEWER. Creates a DRAFT (optional `translation`, `grading`, `explanation`, `categoryIds`) |
| GET | `/admin/hadiths/:id` | EDITOR, REVIEWER. Any status |
| PATCH | `/admin/hadiths/:id` | EDITOR (DRAFT only), REVIEWER. Writes `content_change_history` (before/after JSON) |
| POST | `/admin/hadiths/:id/submit` | EDITOR, REVIEWER. DRAFT to PENDING_REVIEW, creates a `content_reviews` row |
| GET | `/admin/pending-reviews` | REVIEWER |
| POST | `/admin/content-reviews/:id/decision` | REVIEWER. `{decision: APPROVED or REJECTED, notes?}` |

## Content workflow

1. An **EDITOR** creates a hadith (`POST /admin/hadiths`). It is stored as `DRAFT` with its translation/explanation also `DRAFT`.
2. The editor edits it while it is still a draft. Every change is recorded in `content_change_history`.
3. The editor submits it (`/submit`). The hadith becomes `PENDING_REVIEW` and a `content_reviews` row is created.
4. A **REVIEWER** (who is not the submitter; only ADMIN may approve their own submission) decides:
   - **APPROVED**: refused with **422** unless `sourceReference` is set **and** at least one grading has a `source`. On success the hadith and its draft/pending translations and explanations become `PUBLISHED` and appear in the public API.
   - **REJECTED**: back to `DRAFT` with reviewer notes.
5. Translations/explanations added later via PATCH start as `DRAFT` and stay hidden until the hadith goes through review again.

Roles live in `users.role` (`USER`, `EDITOR`, `REVIEWER`, `ADMIN`). The `admin_roles` table is reserved for future fine-grained grants and is not used for authorization yet. To promote a user, update `users.role` in SQL, or seed an admin with `SEED_ADMIN_*`.

## Data model notes

- Tables are snake_case (`hadith_books`, `hadiths`, `refresh_tokens`, ...). Prisma fields are camelCase.
- `hadiths.arabic_text_normalized` (tashkeel/tatweel stripped, alef/ya/ta-marbuta unified) and `hadiths.hadith_number_sort` are maintained by the service on create/update.
- GIN trigram indexes (`pg_trgm`) on `hadiths.arabic_text`, `arabic_text_normalized`, `narrator` and `hadith_translations.text` back the `ILIKE` searches.
- Refresh tokens: 48 random bytes, base64url. Only the SHA-256 hash is stored, together with the family id, `revoked_at`, `replaced_by` and `expires_at`.

## Migrations

```bash
# development: edit prisma/schema.prisma, then
npx prisma migrate dev --name describe_change
# production: applied automatically by the Docker entrypoint, or manually
npx prisma migrate deploy
```

Migrations in `prisma/migrations/` are committed and must never be edited after they are deployed.

See [`../docs/DEPLOYMENT_COOLIFY.md`](../docs/DEPLOYMENT_COOLIFY.md) for deployment.
