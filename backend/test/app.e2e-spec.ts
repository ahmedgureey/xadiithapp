/**
 * End-to-end tests against a real PostgreSQL database (see test/setup-env.ts).
 * Fixtures below use OBVIOUS placeholder strings ("TEST ARABIC TEXT" ...). They are
 * test-only data and are deleted at the start of each run; nothing here is seeded.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { normalizeArabic } from '../src/common/arabic/arabic-normalize';
import { PrismaService } from '../src/prisma/prisma.service';
import { setupApp } from '../src/setup-app';

const P = '/api/v1';
// "TEST ARABIC TEXT" + Arabic word with full tashkeel (kataba) for diacritics-insensitive search.
const VOWELLED = 'كَتَبَ';
const BARE = 'كتب';

describe('Xadiis API (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let http: ReturnType<typeof request>;

  let bookId: string;
  let categoryId: string;
  let chapterId: string;
  let publishedId: string;
  let draftId: string;

  const api = () => request(app.getHttpServer());

  async function register(email: string, displayName = 'Test User') {
    const res = await api()
      .post(`${P}/auth/register`)
      .send({ email, password: 'password123', displayName })
      .expect(201);
    return res.body.data as {
      user: { id: string; email: string; role: string };
      accessToken: string;
      refreshToken: string;
    };
  }

  async function login(email: string) {
    const res = await api().post(`${P}/auth/login`).send({ email, password: 'password123' }).expect(200);
    return res.body.data as { accessToken: string; refreshToken: string; user: { id: string } };
  }

  function expectErrorShape(body: Record<string, unknown>, status: number) {
    expect(body).toEqual(
      expect.objectContaining({
        statusCode: status,
        error: expect.any(String),
        path: expect.stringMatching(/^\/api\/v1\//),
        timestamp: expect.any(String),
      }),
    );
    expect(typeof body.message === 'string' || Array.isArray(body.message)).toBe(true);
    expect(Number.isNaN(Date.parse(body.timestamp as string))).toBe(false);
  }

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
    prisma = app.get(PrismaService);
    http = api();
    void http;

    // Clean test data (keeps seeded books/categories).
    await prisma.$executeRawUnsafe(
      'TRUNCATE TABLE "content_change_history", "content_reviews", "refresh_tokens", "bookmarks", "memorization_progress", "reading_history", "hadith_categories", "hadith_translations", "hadith_gradings", "hadith_explanations", "hadiths", "hadith_chapters", "admin_roles", "user_notification_settings", "profiles", "users" CASCADE',
    );

    const book = await prisma.hadithBook.findUniqueOrThrow({ where: { slug: 'sahih-bukhari' } });
    bookId = book.id;
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: 'iman' } });
    categoryId = cat.id;

    const chapter = await prisma.hadithChapter.create({
      data: {
        bookId,
        number: 9001,
        titleArabic: 'TEST CHAPTER AR',
        titleSomali: 'TEST CHAPTER SO',
        titleEnglish: 'TEST CHAPTER EN',
      },
    });
    chapterId = chapter.id;

    const arabic = `TEST ARABIC TEXT ${VOWELLED}`;
    const published = await prisma.hadith.create({
      data: {
        bookId,
        chapterId,
        hadithNumber: '9001',
        hadithNumberSort: 9001,
        arabicText: arabic,
        arabicTextNormalized: normalizeArabic(arabic),
        narrator: 'TEST NARRATOR',
        sourceReference: 'TEST SOURCE REFERENCE',
        status: 'PUBLISHED',
        publishedAt: new Date(),
        translations: {
          create: [
            { language: 'so', text: 'TEST SOMALI TRANSLATION', translator: 'TEST TRANSLATOR', status: 'PUBLISHED' },
            { language: 'so', text: 'TEST UNPUBLISHED TRANSLATION', status: 'DRAFT' },
          ],
        },
        gradings: { create: { grade: 'TEST GRADE', gradedBy: 'TEST SCHOLAR', source: 'TEST GRADING SOURCE' } },
        explanations: {
          create: [
            { language: 'so', text: 'TEST EXPLANATION', status: 'PUBLISHED' },
            { language: 'so', text: 'TEST DRAFT EXPLANATION', status: 'DRAFT' },
          ],
        },
        categories: { create: { categoryId } },
      },
    });
    publishedId = published.id;

    const draft = await prisma.hadith.create({
      data: {
        bookId,
        hadithNumber: '9002',
        hadithNumberSort: 9002,
        arabicText: 'TEST DRAFT ARABIC TEXT',
        arabicTextNormalized: 'TEST DRAFT ARABIC TEXT',
        narrator: 'TEST NARRATOR',
        status: 'DRAFT',
        categories: { create: { categoryId } },
      },
    });
    draftId = draft.id;
  });

  afterAll(async () => {
    await app?.close();
  });

  // ---------------------------------------------------------------- public
  describe('health', () => {
    it('GET /health -> ok/up with version', async () => {
      const res = await api().get(`${P}/health`).expect(200);
      expect(res.body).toEqual({
        status: 'ok',
        database: 'up',
        version: '1.0.0',
        timestamp: expect.any(String),
      });
    });
  });

  describe('books & chapters', () => {
    it('GET /books lists 6 seeded books sorted by sortOrder with counts', async () => {
      const res = await api().get(`${P}/books`).expect(200);
      expect(res.body.meta).toEqual({ page: 1, limit: 20, total: 6, totalPages: 1 });
      const slugs = res.body.data.map((b: { slug: string }) => b.slug);
      expect(slugs).toEqual([
        'sahih-bukhari',
        'sahih-muslim',
        'sunan-abi-dawud',
        'jami-tirmidhi',
        'sunan-nasai',
        'sunan-ibn-majah',
      ]);
      const bukhari = res.body.data[0];
      expect(Object.keys(bukhari).sort()).toEqual(
        [
          'id',
          'slug',
          'nameArabic',
          'nameSomali',
          'nameEnglish',
          'authorName',
          'descriptionSomali',
          'sortOrder',
          'hadithCount',
          'chapterCount',
        ].sort(),
      );
      expect(bukhari.hadithCount).toBe(1); // draft excluded
      expect(bukhari.chapterCount).toBe(1);
      expect(bukhari.nameArabic).toBe('صحيح البخاري');
    });

    it('pagination meta and limit bounds', async () => {
      const res = await api().get(`${P}/books?page=2&limit=4`).expect(200);
      expect(res.body.meta).toEqual({ page: 2, limit: 4, total: 6, totalPages: 2 });
      expect(res.body.data).toHaveLength(2);
      const bad = await api().get(`${P}/books?limit=101`).expect(400);
      expectErrorShape(bad.body, 400);
    });

    it('GET /books/:slug and /books/:uuid', async () => {
      const bySlug = await api().get(`${P}/books/sahih-bukhari`).expect(200);
      expect(bySlug.body.data.id).toBe(bookId);
      const byId = await api().get(`${P}/books/${bookId}`).expect(200);
      expect(byId.body.data.slug).toBe('sahih-bukhari');
    });

    it('GET /books/:unknown -> 404 error shape', async () => {
      const res = await api().get(`${P}/books/does-not-exist`).expect(404);
      expectErrorShape(res.body, 404);
      expect(res.body.error).toBe('Not Found');
      expect(res.body.path).toBe('/api/v1/books/does-not-exist');
    });

    it('GET /books/:id/chapters', async () => {
      const res = await api().get(`${P}/books/sahih-bukhari/chapters`).expect(200);
      expect(res.body.meta.total).toBe(1);
      expect(res.body.data[0]).toEqual({
        id: chapterId,
        bookId,
        number: 9001,
        titleArabic: 'TEST CHAPTER AR',
        titleSomali: 'TEST CHAPTER SO',
        titleEnglish: 'TEST CHAPTER EN',
        hadithCount: 1,
      });
    });
  });

  describe('categories', () => {
    it('GET /categories lists 10 seeded categories with published counts', async () => {
      const res = await api().get(`${P}/categories`).expect(200);
      expect(res.body.meta.total).toBe(10);
      expect(res.body.data[0]).toEqual({
        id: categoryId,
        slug: 'iman',
        nameSomali: 'Iimaanka',
        nameArabic: 'الإيمان',
        nameEnglish: 'Faith',
        icon: 'favorite',
        hadithCount: 1,
      });
      expect(res.body.data.map((c: { slug: string }) => c.slug)).toEqual([
        'iman',
        'salah',
        'sawm',
        'zakah',
        'hajj',
        'tahara',
        'akhlaq',
        'ilm',
        'family',
        'dua',
      ]);
    });
  });

  describe('hadiths (published only)', () => {
    it('GET /hadiths returns only PUBLISHED hadiths and PUBLISHED translations/explanations', async () => {
      const res = await api().get(`${P}/hadiths`).expect(200);
      expect(res.body.meta.total).toBe(1);
      const h = res.body.data[0];
      expect(h.id).toBe(publishedId);
      expect(Object.keys(h).sort()).toEqual(
        [
          'id',
          'hadithNumber',
          'arabicText',
          'narrator',
          'sourceReference',
          'book',
          'chapter',
          'translations',
          'gradings',
          'explanations',
          'categories',
          'updatedAt',
        ].sort(),
      );
      expect(Object.keys(h.book).sort()).toEqual(
        ['id', 'slug', 'nameArabic', 'nameSomali', 'nameEnglish'].sort(),
      );
      expect(h.chapter).toEqual({
        id: chapterId,
        number: 9001,
        titleArabic: 'TEST CHAPTER AR',
        titleSomali: 'TEST CHAPTER SO',
        titleEnglish: 'TEST CHAPTER EN',
      });
      expect(h.translations).toHaveLength(1);
      expect(h.translations[0]).toEqual({
        id: expect.any(String),
        language: 'so',
        text: 'TEST SOMALI TRANSLATION',
        translator: 'TEST TRANSLATOR',
        source: null,
      });
      expect(h.explanations.map((e: { text: string }) => e.text)).toEqual(['TEST EXPLANATION']);
      expect(Object.keys(h.explanations[0]).sort()).toEqual(
        ['id', 'language', 'text', 'author', 'source'].sort(),
      );
      expect(h.gradings[0]).toEqual({
        id: expect.any(String),
        grade: 'TEST GRADE',
        gradedBy: 'TEST SCHOLAR',
        source: 'TEST GRADING SOURCE',
      });
      expect(h.categories[0]).toEqual({
        id: categoryId,
        slug: 'iman',
        nameSomali: 'Iimaanka',
        nameArabic: 'الإيمان',
        nameEnglish: 'Faith',
      });
    });

    it('filters by bookId/chapterId/categoryId', async () => {
      const byCat = await api().get(`${P}/hadiths?categoryId=${categoryId}`).expect(200);
      expect(byCat.body.meta.total).toBe(1);
      const byChapter = await api().get(`${P}/hadiths?chapterId=${chapterId}`).expect(200);
      expect(byChapter.body.meta.total).toBe(1);
      const muslim = await prisma.hadithBook.findUniqueOrThrow({ where: { slug: 'sahih-muslim' } });
      const byOtherBook = await api().get(`${P}/hadiths?bookId=${muslim.id}`).expect(200);
      expect(byOtherBook.body.meta.total).toBe(0);
      await api().get(`${P}/hadiths?bookId=not-a-uuid`).expect(400);
    });

    it('GET /hadiths/:id -> 200 for published, 404 for draft, 400 for bad uuid', async () => {
      const ok = await api().get(`${P}/hadiths/${publishedId}`).expect(200);
      expect(ok.body.data.hadithNumber).toBe('9001');
      const nf = await api().get(`${P}/hadiths/${draftId}`).expect(404);
      expectErrorShape(nf.body, 404);
      await api().get(`${P}/hadiths/abc`).expect(400);
    });

    it('GET /hadith-of-the-day returns a published hadith', async () => {
      const res = await api().get(`${P}/hadith-of-the-day`).expect(200);
      expect(res.body.data.id).toBe(publishedId);
    });
  });

  describe('search', () => {
    const search = (q: string) => api().get(`${P}/search?q=${encodeURIComponent(q)}`);

    it('matches Arabic text but never drafts', async () => {
      const res = await search('TEST ARABIC').expect(200);
      expect(res.body.data.map((h: { id: string }) => h.id)).toEqual([publishedId]);
      const draftOnly = await search('TEST DRAFT ARABIC').expect(200);
      expect(draftOnly.body.meta.total).toBe(0);
    });

    it('is diacritics-insensitive for Arabic (bare query matches vowelled text and vice versa)', async () => {
      expect((await search(BARE).expect(200)).body.meta.total).toBe(1);
      expect((await search(VOWELLED).expect(200)).body.meta.total).toBe(1);
    });

    it('matches published Somali translation, narrator, book name, hadith number', async () => {
      expect((await search('test somali').expect(200)).body.meta.total).toBe(1);
      expect((await search('TEST UNPUBLISHED TRANSLATION').expect(200)).body.meta.total).toBe(0);
      expect((await search('test narrator').expect(200)).body.meta.total).toBe(1);
      expect((await search('Bukhari').expect(200)).body.meta.total).toBe(1);
      expect((await search('Saxiix al-Bukhaari').expect(200)).body.meta.total).toBe(1);
      expect((await search('9001').expect(200)).body.meta.total).toBe(1);
      expect((await search('9002').expect(200)).body.meta.total).toBe(0);
      expect((await search('nothing-matches-this').expect(200)).body.meta.total).toBe(0);
    });

    it('applies bookId/categoryId filters', async () => {
      const muslim = await prisma.hadithBook.findUniqueOrThrow({ where: { slug: 'sahih-muslim' } });
      const res = await api().get(`${P}/search?q=TEST&bookId=${muslim.id}`).expect(200);
      expect(res.body.meta.total).toBe(0);
      const res2 = await api().get(`${P}/search?q=TEST&categoryId=${categoryId}`).expect(200);
      expect(res2.body.meta.total).toBe(1);
    });

    it('q is required (400) and must not be blank', async () => {
      const missing = await api().get(`${P}/search`).expect(400);
      expectErrorShape(missing.body, 400);
      expect(Array.isArray(missing.body.message)).toBe(true);
      await search('   ').expect(400);
    });
  });

  // ---------------------------------------------------------------- auth
  describe('auth', () => {
    it('register -> 201 AuthResult; duplicate -> 409; email normalised', async () => {
      const res = await api()
        .post(`${P}/auth/register`)
        .send({ email: '  Auth.User@Example.COM ', password: 'password123', displayName: 'Auth User' })
        .expect(201);
      const d = res.body.data;
      expect(Object.keys(d).sort()).toEqual(
        ['user', 'accessToken', 'refreshToken', 'accessTokenExpiresIn'].sort(),
      );
      expect(d.accessTokenExpiresIn).toBe(900);
      expect(d.user).toEqual({
        id: expect.any(String),
        email: 'auth.user@example.com',
        role: 'USER',
        createdAt: expect.any(String),
        profile: { displayName: 'Auth User', preferredLanguage: 'so' },
      });
      expect(JSON.stringify(d)).not.toContain('password');

      const dup = await api()
        .post(`${P}/auth/register`)
        .send({ email: 'auth.user@example.com', password: 'password123', displayName: 'Dup' })
        .expect(409);
      expectErrorShape(dup.body, 409);
    });

    it('validation errors -> 400 with message array', async () => {
      const res = await api()
        .post(`${P}/auth/register`)
        .send({ email: 'not-an-email', password: 'short', displayName: '', extra: 'x' })
        .expect(400);
      expectErrorShape(res.body, 400);
      expect(res.body.error).toBe('Bad Request');
      expect(Array.isArray(res.body.message)).toBe(true);
      const joined = (res.body.message as string[]).join(' | ');
      expect(joined).toMatch(/email/);
      expect(joined).toMatch(/password/);
      expect(joined).toMatch(/extra should not exist/);
    });

    it('login -> 200; wrong password / unknown email -> generic 401', async () => {
      await login('auth.user@example.com');
      const wrong = await api()
        .post(`${P}/auth/login`)
        .send({ email: 'auth.user@example.com', password: 'wrong-password' })
        .expect(401);
      expectErrorShape(wrong.body, 401);
      expect(wrong.body.message).toBe('Invalid email or password');
      const unknown = await api()
        .post(`${P}/auth/login`)
        .send({ email: 'nobody@example.com', password: 'whatever123' })
        .expect(401);
      expect(unknown.body.message).toBe('Invalid email or password');
    });

    it('refresh rotates; reusing the old token revokes the family; logout -> 204', async () => {
      const first = await login('auth.user@example.com');
      const r1 = await api().post(`${P}/auth/refresh`).send({ refreshToken: first.refreshToken }).expect(200);
      const second = r1.body.data;
      expect(second.refreshToken).not.toBe(first.refreshToken);
      expect(second.accessToken).toEqual(expect.any(String));

      // Reuse of the rotated token -> 401 and the whole family is revoked.
      await api().post(`${P}/auth/refresh`).send({ refreshToken: first.refreshToken }).expect(401);
      await api().post(`${P}/auth/refresh`).send({ refreshToken: second.refreshToken }).expect(401);

      // Stored tokens are hashes only.
      const rows = await prisma.refreshToken.findMany();
      expect(rows.some((t) => t.tokenHash === first.refreshToken)).toBe(false);

      const fresh = await login('auth.user@example.com');
      await api().post(`${P}/auth/logout`).send({ refreshToken: fresh.refreshToken }).expect(204);
      await api().post(`${P}/auth/refresh`).send({ refreshToken: fresh.refreshToken }).expect(401);
      await api().post(`${P}/auth/refresh`).send({ refreshToken: 'garbage' }).expect(401);
    });
  });

  // ---------------------------------------------------------------- user data
  describe('authenticated user endpoints', () => {
    let a: { accessToken: string; user: { id: string } };
    let b: { accessToken: string; user: { id: string } };
    const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

    beforeAll(async () => {
      a = await register('alice@example.com', 'Alice');
      b = await register('bilan@example.com', 'Bilan');
    });

    it('401 without/with invalid token', async () => {
      const res = await api().get(`${P}/me`).expect(401);
      expectErrorShape(res.body, 401);
      await api().get(`${P}/bookmarks`).set('Authorization', 'Bearer nope').expect(401);
    });

    it('GET/PATCH /me', async () => {
      const me = await api().get(`${P}/me`).set(auth(a.accessToken)).expect(200);
      expect(me.body.data.email).toBe('alice@example.com');
      const upd = await api()
        .patch(`${P}/me`)
        .set(auth(a.accessToken))
        .send({ displayName: 'Alice X', preferredLanguage: 'en' })
        .expect(200);
      expect(upd.body.data.profile).toEqual({ displayName: 'Alice X', preferredLanguage: 'en' });
      await api().patch(`${P}/me`).set(auth(a.accessToken)).send({ preferredLanguage: 'fr' }).expect(400);
    });

    it('notification settings GET/PUT', async () => {
      const g = await api().get(`${P}/me/notification-settings`).set(auth(a.accessToken)).expect(200);
      expect(g.body.data).toEqual({ dailyHadith: true, reviewReminders: true, reminderTime: '08:00' });
      const p = await api()
        .put(`${P}/me/notification-settings`)
        .set(auth(a.accessToken))
        .send({ dailyHadith: false, reviewReminders: true, reminderTime: '21:30' })
        .expect(200);
      expect(p.body.data).toEqual({ dailyHadith: false, reviewReminders: true, reminderTime: '21:30' });
      await api()
        .put(`${P}/me/notification-settings`)
        .set(auth(a.accessToken))
        .send({ dailyHadith: false, reviewReminders: true, reminderTime: '25:00' })
        .expect(400);
    });

    it('bookmarks: create (idempotent), ownership isolation, delete by hadithId', async () => {
      const c1 = await api()
        .post(`${P}/bookmarks`)
        .set(auth(a.accessToken))
        .send({ hadithId: publishedId })
        .expect(201);
      expect(Object.keys(c1.body.data).sort()).toEqual(['id', 'hadithId', 'createdAt', 'hadith'].sort());
      expect(c1.body.data.hadith.id).toBe(publishedId);
      const c2 = await api()
        .post(`${P}/bookmarks`)
        .set(auth(a.accessToken))
        .send({ hadithId: publishedId })
        .expect(201);
      expect(c2.body.data.id).toBe(c1.body.data.id);

      await api().post(`${P}/bookmarks`).set(auth(a.accessToken)).send({ hadithId: draftId }).expect(404);

      const listA = await api().get(`${P}/bookmarks`).set(auth(a.accessToken)).expect(200);
      expect(listA.body.meta.total).toBe(1);
      const listB = await api().get(`${P}/bookmarks`).set(auth(b.accessToken)).expect(200);
      expect(listB.body.meta.total).toBe(0);

      // B "deleting" the hadith bookmark does not touch A's bookmark.
      await api().delete(`${P}/bookmarks/${publishedId}`).set(auth(b.accessToken)).expect(204);
      expect((await api().get(`${P}/bookmarks`).set(auth(a.accessToken))).body.meta.total).toBe(1);

      await api().delete(`${P}/bookmarks/${publishedId}`).set(auth(a.accessToken)).expect(204);
      expect((await api().get(`${P}/bookmarks`).set(auth(a.accessToken))).body.meta.total).toBe(0);
    });

    it('memorization: create, SM-2 quality patch, status patch, due filter, ownership, delete', async () => {
      const created = await api()
        .post(`${P}/memorization`)
        .set(auth(a.accessToken))
        .send({ hadithId: publishedId })
        .expect(201);
      const m = created.body.data;
      expect(Object.keys(m).sort()).toEqual(
        [
          'id',
          'hadithId',
          'status',
          'repetitions',
          'easeFactor',
          'intervalDays',
          'nextReviewAt',
          'lastReviewedAt',
          'createdAt',
          'hadith',
        ].sort(),
      );
      expect(m).toEqual(
        expect.objectContaining({ status: 'NEW', repetitions: 0, easeFactor: 2.5, intervalDays: 0, lastReviewedAt: null }),
      );

      const due = await api().get(`${P}/memorization?due=true`).set(auth(a.accessToken)).expect(200);
      expect(due.body.meta.total).toBe(1);

      const q = await api()
        .patch(`${P}/memorization/${m.id}`)
        .set(auth(a.accessToken))
        .send({ quality: 4 })
        .expect(200);
      expect(q.body.data).toEqual(
        expect.objectContaining({ status: 'REVIEWING', repetitions: 1, intervalDays: 1, easeFactor: 2.5 }),
      );
      expect(Date.parse(q.body.data.nextReviewAt)).toBeGreaterThan(Date.now() + 23 * 3600 * 1000);
      expect(q.body.data.lastReviewedAt).toEqual(expect.any(String));

      const q2 = await api()
        .patch(`${P}/memorization/${m.id}`)
        .set(auth(a.accessToken))
        .send({ quality: 5 })
        .expect(200);
      expect(q2.body.data).toEqual(expect.objectContaining({ repetitions: 2, intervalDays: 6, easeFactor: 2.6 }));

      const fail = await api()
        .patch(`${P}/memorization/${m.id}`)
        .set(auth(a.accessToken))
        .send({ quality: 1 })
        .expect(200);
      expect(fail.body.data).toEqual(expect.objectContaining({ status: 'LEARNING', repetitions: 0, intervalDays: 1 }));

      const notDue = await api().get(`${P}/memorization?due=true`).set(auth(a.accessToken)).expect(200);
      expect(notDue.body.meta.total).toBe(0);

      const st = await api()
        .patch(`${P}/memorization/${m.id}`)
        .set(auth(a.accessToken))
        .send({ status: 'MEMORIZED' })
        .expect(200);
      expect(st.body.data.status).toBe('MEMORIZED');
      const byStatus = await api().get(`${P}/memorization?status=MEMORIZED`).set(auth(a.accessToken)).expect(200);
      expect(byStatus.body.meta.total).toBe(1);

      await api().patch(`${P}/memorization/${m.id}`).set(auth(a.accessToken)).send({ quality: 6 }).expect(400);
      await api().patch(`${P}/memorization/${m.id}`).set(auth(a.accessToken)).send({}).expect(400);

      // Another user's record is invisible (404).
      await api().patch(`${P}/memorization/${m.id}`).set(auth(b.accessToken)).send({ quality: 5 }).expect(404);
      await api().delete(`${P}/memorization/${m.id}`).set(auth(b.accessToken)).expect(404);
      expect((await api().get(`${P}/memorization`).set(auth(b.accessToken))).body.meta.total).toBe(0);

      await api().delete(`${P}/memorization/${m.id}`).set(auth(a.accessToken)).expect(204);
      expect((await api().get(`${P}/memorization`).set(auth(a.accessToken))).body.meta.total).toBe(0);
    });

    it('reading history: upsert keeps one row per hadith, newest first', async () => {
      const r1 = await api()
        .post(`${P}/reading-history`)
        .set(auth(a.accessToken))
        .send({ hadithId: publishedId })
        .expect(201);
      expect(Object.keys(r1.body.data).sort()).toEqual(['id', 'hadithId', 'viewedAt', 'hadith'].sort());
      const r2 = await api()
        .post(`${P}/reading-history`)
        .set(auth(a.accessToken))
        .send({ hadithId: publishedId })
        .expect(201);
      expect(r2.body.data.id).toBe(r1.body.data.id);
      expect(Date.parse(r2.body.data.viewedAt)).toBeGreaterThanOrEqual(Date.parse(r1.body.data.viewedAt));
      const list = await api().get(`${P}/reading-history`).set(auth(a.accessToken)).expect(200);
      expect(list.body.meta.total).toBe(1);
      await api().post(`${P}/reading-history`).set(auth(a.accessToken)).send({ hadithId: draftId }).expect(404);
    });
  });

  // ---------------------------------------------------------------- admin
  describe('admin content workflow', () => {
    let user: string;
    let editor: string;
    let reviewer: string;
    let editorId: string;
    const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

    beforeAll(async () => {
      user = (await register('plain@example.com')).accessToken;
      const e = await register('editor@example.com');
      const r = await register('reviewer@example.com');
      editorId = e.user.id;
      await prisma.user.update({ where: { id: e.user.id }, data: { role: 'EDITOR' } });
      await prisma.user.update({ where: { id: r.user.id }, data: { role: 'REVIEWER' } });
      editor = (await login('editor@example.com')).accessToken;
      reviewer = (await login('reviewer@example.com')).accessToken;
    });

    const newHadith = (n: string, extra: Record<string, unknown> = {}) => ({
      bookId,
      hadithNumber: n,
      arabicText: `TEST ADMIN ARABIC ${n}`,
      narrator: 'TEST ADMIN NARRATOR',
      translation: { language: 'so', text: `TEST ADMIN SOMALI ${n}`, translator: 'TEST' },
      categoryIds: [categoryId],
      ...extra,
    });

    it('plain USER gets 403 on admin endpoints; no token gets 401', async () => {
      const res = await api().post(`${P}/admin/hadiths`).set(auth(user)).send(newHadith('9100')).expect(403);
      expectErrorShape(res.body, 403);
      await api().post(`${P}/admin/hadiths`).send(newHadith('9100')).expect(401);
      await api().get(`${P}/admin/pending-reviews`).set(auth(editor)).expect(403);
    });

    it('editor creates -> submits -> publish blocked without source -> reject -> fix -> approve -> public', async () => {
      const created = await api()
        .post(`${P}/admin/hadiths`)
        .set(auth(editor))
        .send(newHadith('9101', { grading: { grade: 'TEST GRADE', gradedBy: 'TEST SCHOLAR' } }))
        .expect(201);
      const h = created.body.data;
      expect(h.status).toBe('DRAFT');
      expect(h.translations[0].status).toBe('DRAFT');

      // Duplicate number in same book -> 409
      await api().post(`${P}/admin/hadiths`).set(auth(editor)).send(newHadith('9101')).expect(409);

      // Not public yet
      await api().get(`${P}/hadiths/${h.id}`).expect(404);

      const sub = await api().post(`${P}/admin/hadiths/${h.id}/submit`).set(auth(editor)).expect(200);
      expect(sub.body.data.hadith.status).toBe('PENDING_REVIEW');
      const reviewId = sub.body.data.id;

      // Editors cannot edit once submitted
      await api().patch(`${P}/admin/hadiths/${h.id}`).set(auth(editor)).send({ narrator: 'X' }).expect(409);

      const pending = await api().get(`${P}/admin/pending-reviews`).set(auth(reviewer)).expect(200);
      expect(pending.body.meta.total).toBe(1);
      expect(pending.body.data[0].hadith.id).toBe(h.id);

      // Missing sourceReference + grading source -> publish refused (422)
      const blocked = await api()
        .post(`${P}/admin/content-reviews/${reviewId}/decision`)
        .set(auth(reviewer))
        .send({ decision: 'APPROVED' })
        .expect(422);
      expectErrorShape(blocked.body, 422);
      expect(blocked.body.message).toEqual(
        expect.arrayContaining([
          'sourceReference is required to publish',
          'at least one grading with a source is required to publish',
        ]),
      );
      await api().get(`${P}/hadiths/${h.id}`).expect(404);

      const rejected = await api()
        .post(`${P}/admin/content-reviews/${reviewId}/decision`)
        .set(auth(reviewer))
        .send({ decision: 'REJECTED', notes: 'Add sources' })
        .expect(200);
      expect(rejected.body.data.status).toBe('REJECTED');
      expect(rejected.body.data.hadith.status).toBe('DRAFT');

      // Editor fixes the draft (change history recorded)
      const patched = await api()
        .patch(`${P}/admin/hadiths/${h.id}`)
        .set(auth(editor))
        .send({
          sourceReference: 'TEST SOURCE REF 9101',
          grading: { grade: 'TEST GRADE', gradedBy: 'TEST SCHOLAR', source: 'TEST GRADING SOURCE' },
        })
        .expect(200);
      expect(patched.body.data.sourceReference).toBe('TEST SOURCE REF 9101');
      expect(patched.body.data.gradings).toHaveLength(2);

      const history = await prisma.contentChangeHistory.findMany({
        where: { entityId: h.id },
        orderBy: { createdAt: 'asc' },
      });
      const update = history.find((x) => x.action === 'UPDATE');
      expect(update).toBeDefined();
      expect((update!.before as { sourceReference: string | null }).sourceReference).toBeNull();
      expect((update!.after as { sourceReference: string }).sourceReference).toBe('TEST SOURCE REF 9101');
      expect(update!.changedById).toBe(editorId);

      const sub2 = await api().post(`${P}/admin/hadiths/${h.id}/submit`).set(auth(editor)).expect(200);
      const approved = await api()
        .post(`${P}/admin/content-reviews/${sub2.body.data.id}/decision`)
        .set(auth(reviewer))
        .send({ decision: 'APPROVED', notes: 'OK' })
        .expect(200);
      expect(approved.body.data.status).toBe('APPROVED');
      expect(approved.body.data.hadith.status).toBe('PUBLISHED');

      // Deciding twice -> 409
      await api()
        .post(`${P}/admin/content-reviews/${sub2.body.data.id}/decision`)
        .set(auth(reviewer))
        .send({ decision: 'APPROVED' })
        .expect(409);

      // Now public, with its translation published
      const pub = await api().get(`${P}/hadiths/${h.id}`).expect(200);
      expect(pub.body.data.translations.map((t: { text: string }) => t.text)).toEqual(['TEST ADMIN SOMALI 9101']);
      expect(pub.body.data.categories[0].slug).toBe('iman');
      const s = await api().get(`${P}/search?q=${encodeURIComponent('TEST ADMIN SOMALI 9101')}`).expect(200);
      expect(s.body.meta.total).toBe(1);
      expect(history.map((x) => x.action)).toEqual(['CREATE', 'SUBMIT', 'REJECT', 'UPDATE']);
    });

    it('reviewer cannot approve own submission', async () => {
      const created = await api()
        .post(`${P}/admin/hadiths`)
        .set(auth(reviewer))
        .send(
          newHadith('9102', {
            sourceReference: 'TEST SRC',
            grading: { grade: 'TEST', source: 'TEST GRADING SOURCE' },
          }),
        )
        .expect(201);
      const sub = await api()
        .post(`${P}/admin/hadiths/${created.body.data.id}/submit`)
        .set(auth(reviewer))
        .expect(200);
      const res = await api()
        .post(`${P}/admin/content-reviews/${sub.body.data.id}/decision`)
        .set(auth(reviewer))
        .send({ decision: 'APPROVED' })
        .expect(403);
      expectErrorShape(res.body, 403);
      await api().get(`${P}/hadiths/${created.body.data.id}`).expect(404);
    });
  });

  // ---------------------------------------------------------------- throttling
  describe('rate limiting', () => {
    it('auth endpoints return 429 once AUTH_THROTTLE_LIMIT is exceeded', async () => {
      const previous = process.env.AUTH_THROTTLE_LIMIT;
      process.env.AUTH_THROTTLE_LIMIT = '3';
      try {
        const statuses: number[] = [];
        for (let i = 0; i < 6; i++) {
          const r = await api()
            .post(`${P}/auth/login`)
            .send({ email: 'ratelimit@example.com', password: 'whatever123' });
          statuses.push(r.status);
          if (r.status === 429) expectErrorShape(r.body, 429);
        }
        expect(statuses).toContain(429);
        // health is never throttled
        await api().get(`${P}/health`).expect(200);
      } finally {
        process.env.AUTH_THROTTLE_LIMIT = previous;
      }
    });
  });
});
