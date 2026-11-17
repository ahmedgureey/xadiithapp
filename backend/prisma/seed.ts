/**
 * Idempotent seed. Seeds ONLY reference metadata (books, categories) and an
 * optional admin user. It intentionally seeds NO hadith text, translations,
 * gradings or explanations: religious content must be entered through the
 * admin review workflow with verified sources.
 */
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const books = [
  {
    slug: 'sahih-bukhari',
    nameArabic: 'صحيح البخاري',
    nameSomali: 'Saxiix al-Bukhaari',
    nameEnglish: 'Sahih al-Bukhari',
    authorName: 'Muhammad ibn Ismail al-Bukhari',
  },
  {
    slug: 'sahih-muslim',
    nameArabic: 'صحيح مسلم',
    nameSomali: 'Saxiix Muslim',
    nameEnglish: 'Sahih Muslim',
    authorName: 'Muslim ibn al-Hajjaj',
  },
  {
    slug: 'sunan-abi-dawud',
    nameArabic: 'سنن أبي داود',
    nameSomali: 'Sunan Abii Daawuud',
    nameEnglish: 'Sunan Abi Dawud',
    authorName: 'Abu Dawud al-Sijistani',
  },
  {
    slug: 'jami-tirmidhi',
    nameArabic: 'جامع الترمذي',
    nameSomali: 'Jaamic at-Tirmidi',
    nameEnglish: "Jami' at-Tirmidhi",
    authorName: 'Abu Isa al-Tirmidhi',
  },
  {
    slug: 'sunan-nasai',
    nameArabic: 'سنن النسائي',
    nameSomali: "Sunan an-Nasaa'i",
    nameEnglish: "Sunan an-Nasa'i",
    authorName: "Ahmad ibn Shu'ayb al-Nasa'i",
  },
  {
    slug: 'sunan-ibn-majah',
    nameArabic: 'سنن ابن ماجه',
    nameSomali: 'Sunan Ibn Maajah',
    nameEnglish: 'Sunan Ibn Majah',
    authorName: 'Ibn Majah al-Qazwini',
  },
];

const categories = [
  { slug: 'iman', nameSomali: 'Iimaanka', nameArabic: 'الإيمان', nameEnglish: 'Faith', icon: 'favorite' },
  { slug: 'salah', nameSomali: 'Salaadda', nameArabic: 'الصلاة', nameEnglish: 'Prayer', icon: 'mosque' },
  { slug: 'sawm', nameSomali: 'Soonka', nameArabic: 'الصوم', nameEnglish: 'Fasting', icon: 'nightlight' },
  { slug: 'zakah', nameSomali: 'Sakada', nameArabic: 'الزكاة', nameEnglish: 'Charity', icon: 'volunteer_activism' },
  { slug: 'hajj', nameSomali: 'Xajka', nameArabic: 'الحج', nameEnglish: 'Pilgrimage', icon: 'explore' },
  { slug: 'tahara', nameSomali: 'Daahirnimada', nameArabic: 'الطهارة', nameEnglish: 'Purification', icon: 'water_drop' },
  { slug: 'akhlaq', nameSomali: 'Akhlaaqda', nameArabic: 'الأخلاق', nameEnglish: 'Character', icon: 'emoji_people' },
  { slug: 'ilm', nameSomali: 'Cilmiga', nameArabic: 'العلم', nameEnglish: 'Knowledge', icon: 'menu_book' },
  { slug: 'family', nameSomali: 'Qoyska', nameArabic: 'الأسرة', nameEnglish: 'Family', icon: 'family_restroom' },
  { slug: 'dua', nameSomali: 'Ducada', nameArabic: 'الدعاء', nameEnglish: 'Supplication', icon: 'front_hand' },
];

async function main(): Promise<void> {
  for (const [i, b] of books.entries()) {
    const data = { ...b, sortOrder: i + 1 };
    await prisma.hadithBook.upsert({ where: { slug: b.slug }, create: data, update: data });
  }
  console.log(`Seeded ${books.length} books`);

  for (const [i, c] of categories.entries()) {
    const data = { ...c, sortOrder: i + 1 };
    await prisma.category.upsert({ where: { slug: c.slug }, create: data, update: data });
  }
  console.log(`Seeded ${categories.length} categories`);

  const adminEmail = process.env.SEED_ADMIN_EMAIL?.trim().toLowerCase();
  const adminPassword = process.env.SEED_ADMIN_PASSWORD;
  if (adminEmail && adminPassword) {
    if (adminPassword.length < 12) {
      throw new Error('SEED_ADMIN_PASSWORD must be at least 12 characters');
    }
    const existing = await prisma.user.findUnique({ where: { email: adminEmail } });
    if (existing) {
      if (existing.role !== 'ADMIN') {
        await prisma.user.update({ where: { id: existing.id }, data: { role: 'ADMIN' } });
      }
      console.log('Admin user already exists (password unchanged)');
    } else {
      await prisma.user.create({
        data: {
          email: adminEmail,
          passwordHash: await argon2.hash(adminPassword, { type: argon2.argon2id }),
          role: 'ADMIN',
          profile: { create: { displayName: 'Admin', preferredLanguage: 'so' } },
          notificationSettings: { create: {} },
        },
      });
      console.log('Created admin user');
    }
  } else {
    console.log('SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD not set: skipping admin user');
  }
}

main()
  .catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
