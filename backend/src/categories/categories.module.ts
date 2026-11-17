import { Controller, Get, Injectable, Module, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { paginate, PaginationQueryDto, toPageParams } from '../common/pagination/pagination';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: PaginationQueryDto) {
    const params = toPageParams(query);
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.category.count(),
      this.prisma.category.findMany({
        include: {
          _count: { select: { hadiths: { where: { hadith: { status: 'PUBLISHED' } } } } },
        },
        orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }],
        skip: params.skip,
        take: params.take,
      }),
    ]);
    return paginate(
      rows.map((c) => ({
        id: c.id,
        slug: c.slug,
        nameSomali: c.nameSomali,
        nameArabic: c.nameArabic,
        nameEnglish: c.nameEnglish,
        icon: c.icon,
        hadithCount: c._count.hadiths,
      })),
      total,
      params,
    );
  }
}

@ApiTags('Categories')
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Get()
  @ApiOperation({ summary: 'List categories (sorted by sortOrder)' })
  list(@Query() query: PaginationQueryDto) {
    return this.categories.list(query);
  }
}

@Module({
  controllers: [CategoriesController],
  providers: [CategoriesService],
})
export class CategoriesModule {}
