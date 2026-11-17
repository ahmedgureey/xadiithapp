import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { normalizeArabic } from '../common/arabic/arabic-normalize';
import { paginate, Paginated, toPageParams } from '../common/pagination/pagination';
import { looksLikeHadithNumber } from '../common/utils/hadith-number';
import { PrismaService } from '../prisma/prisma.service';
import { HadithListQueryDto, SearchQueryDto } from './dto/hadith-query.dto';
import { HadithDto, hadithOrderBy, publicHadithInclude, toHadithDto } from './hadith.mapper';

const DAY_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class HadithsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: HadithListQueryDto): Promise<Paginated<HadithDto>> {
    const params = toPageParams(query);
    const where: Prisma.HadithWhereInput = { status: 'PUBLISHED' };
    if (query.bookId) where.bookId = query.bookId;
    if (query.chapterId) where.chapterId = query.chapterId;
    if (query.categoryId) where.categories = { some: { categoryId: query.categoryId } };
    return this.findPage(where, params);
  }

  async getPublished(id: string): Promise<HadithDto> {
    const hadith = await this.prisma.hadith.findFirst({
      where: { id, status: 'PUBLISHED' },
      include: publicHadithInclude,
    });
    if (!hadith) throw new NotFoundException('Hadith not found');
    return toHadithDto(hadith);
  }

  /** Throws 404 unless the hadith exists and is PUBLISHED. */
  async assertPublished(id: string): Promise<void> {
    const count = await this.prisma.hadith.count({ where: { id, status: 'PUBLISHED' } });
    if (count === 0) throw new NotFoundException('Hadith not found');
  }

  async search(query: SearchQueryDto): Promise<Paginated<HadithDto>> {
    const params = toPageParams(query);
    const q = query.q.trim();
    const normalized = normalizeArabic(q);
    const insensitive = (value: string) => ({ contains: value, mode: 'insensitive' as const });

    const or: Prisma.HadithWhereInput[] = [
      { arabicText: insensitive(q) },
      { narrator: insensitive(q) },
      {
        translations: {
          some: { status: 'PUBLISHED', language: 'so', text: insensitive(q) },
        },
      },
      {
        book: {
          OR: [
            { nameArabic: insensitive(q) },
            { nameSomali: insensitive(q) },
            { nameEnglish: insensitive(q) },
          ],
        },
      },
    ];
    if (normalized.length > 0) {
      or.push({ arabicTextNormalized: { contains: normalized } });
      if (normalized !== q) {
        or.push({ book: { nameArabic: insensitive(normalized) } });
      }
    }
    if (looksLikeHadithNumber(q)) {
      or.push({ hadithNumber: { equals: q, mode: 'insensitive' } });
    }

    const where: Prisma.HadithWhereInput = { status: 'PUBLISHED', OR: or };
    if (query.bookId) where.bookId = query.bookId;
    if (query.categoryId) where.categories = { some: { categoryId: query.categoryId } };
    return this.findPage(where, params);
  }

  /** Deterministic per UTC date: (days since epoch) mod published count, ordered by id. */
  async hadithOfTheDay(now: Date = new Date()): Promise<HadithDto | null> {
    const where: Prisma.HadithWhereInput = { status: 'PUBLISHED' };
    const count = await this.prisma.hadith.count({ where });
    if (count === 0) return null;
    const dayIndex = Math.floor(now.getTime() / DAY_MS);
    const skip = dayIndex % count;
    const hadith = await this.prisma.hadith.findFirst({
      where,
      orderBy: { id: 'asc' },
      skip,
      include: publicHadithInclude,
    });
    return hadith ? toHadithDto(hadith) : null;
  }

  private async findPage(
    where: Prisma.HadithWhereInput,
    params: ReturnType<typeof toPageParams>,
  ): Promise<Paginated<HadithDto>> {
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.hadith.count({ where }),
      this.prisma.hadith.findMany({
        where,
        include: publicHadithInclude,
        orderBy: hadithOrderBy,
        skip: params.skip,
        take: params.take,
      }),
    ]);
    return paginate(rows.map(toHadithDto), total, params);
  }
}
