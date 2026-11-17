import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { paginate, PaginationQueryDto, toPageParams } from '../common/pagination/pagination';
import { isUuid } from '../common/utils/hadith-number';
import { PrismaService } from '../prisma/prisma.service';

const bookInclude = {
  _count: {
    select: {
      hadiths: { where: { status: 'PUBLISHED' } },
      chapters: true,
    },
  },
} satisfies Prisma.HadithBookInclude;

type BookRecord = Prisma.HadithBookGetPayload<{ include: typeof bookInclude }>;

function toBookDto(b: BookRecord) {
  return {
    id: b.id,
    slug: b.slug,
    nameArabic: b.nameArabic,
    nameSomali: b.nameSomali,
    nameEnglish: b.nameEnglish,
    authorName: b.authorName,
    descriptionSomali: b.descriptionSomali,
    sortOrder: b.sortOrder,
    hadithCount: b._count.hadiths,
    chapterCount: b._count.chapters,
  };
}

@Injectable()
export class BooksService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: PaginationQueryDto) {
    const params = toPageParams(query);
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.hadithBook.count(),
      this.prisma.hadithBook.findMany({
        include: bookInclude,
        orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }],
        skip: params.skip,
        take: params.take,
      }),
    ]);
    return paginate(rows.map(toBookDto), total, params);
  }

  async get(idOrSlug: string) {
    const book = await this.findBook(idOrSlug);
    return toBookDto(book);
  }

  async chapters(idOrSlug: string, query: PaginationQueryDto) {
    const book = await this.findBook(idOrSlug);
    const params = toPageParams(query);
    const where: Prisma.HadithChapterWhereInput = { bookId: book.id };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.hadithChapter.count({ where }),
      this.prisma.hadithChapter.findMany({
        where,
        include: { _count: { select: { hadiths: { where: { status: 'PUBLISHED' } } } } },
        orderBy: { number: 'asc' },
        skip: params.skip,
        take: params.take,
      }),
    ]);
    return paginate(
      rows.map((c) => ({
        id: c.id,
        bookId: c.bookId,
        number: c.number,
        titleArabic: c.titleArabic,
        titleSomali: c.titleSomali,
        titleEnglish: c.titleEnglish,
        hadithCount: c._count.hadiths,
      })),
      total,
      params,
    );
  }

  private async findBook(idOrSlug: string): Promise<BookRecord> {
    const where: Prisma.HadithBookWhereUniqueInput = isUuid(idOrSlug)
      ? { id: idOrSlug }
      : { slug: idOrSlug.toLowerCase() };
    const book = await this.prisma.hadithBook.findUnique({ where, include: bookInclude });
    if (!book) throw new NotFoundException('Book not found');
    return book;
  }
}
