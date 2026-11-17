import {
  Body,
  Controller,
  Get,
  Injectable,
  Module,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { AuthUser } from '../common/auth/auth.types';
import { CurrentUser } from '../common/auth/decorators';
import { JwtAuthGuard } from '../common/auth/jwt-auth.guard';
import { HadithIdDto } from '../common/dto/hadith-id.dto';
import { paginate, PaginationQueryDto, toPageParams } from '../common/pagination/pagination';
import { publicHadithInclude, toHadithDto } from '../hadiths/hadith.mapper';
import { HadithsModule } from '../hadiths/hadiths.module';
import { HadithsService } from '../hadiths/hadiths.service';
import { PrismaService } from '../prisma/prisma.service';

const include = { hadith: { include: publicHadithInclude } } as const;

@Injectable()
export class ReadingHistoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly hadiths: HadithsService,
  ) {}

  async list(userId: string, query: PaginationQueryDto) {
    const params = toPageParams(query);
    const where = { userId, hadith: { status: 'PUBLISHED' as const } };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.readingHistory.count({ where }),
      this.prisma.readingHistory.findMany({
        where,
        include,
        orderBy: [{ viewedAt: 'desc' }, { id: 'asc' }],
        skip: params.skip,
        take: params.take,
      }),
    ]);
    return paginate(
      rows.map((r) => ({
        id: r.id,
        hadithId: r.hadithId,
        viewedAt: r.viewedAt,
        hadith: toHadithDto(r.hadith),
      })),
      total,
      params,
    );
  }

  async record(userId: string, hadithId: string) {
    await this.hadiths.assertPublished(hadithId);
    const now = new Date();
    const r = await this.prisma.readingHistory.upsert({
      where: { userId_hadithId: { userId, hadithId } },
      create: { userId, hadithId, viewedAt: now },
      update: { viewedAt: now },
      include,
    });
    return { id: r.id, hadithId: r.hadithId, viewedAt: r.viewedAt, hadith: toHadithDto(r.hadith) };
  }
}

@ApiTags('Reading history')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reading-history')
export class ReadingHistoryController {
  constructor(private readonly history: ReadingHistoryService) {}

  @Get()
  @ApiOperation({ summary: 'Recently viewed hadiths (newest first, one entry per hadith)' })
  list(@CurrentUser() user: AuthUser, @Query() query: PaginationQueryDto) {
    return this.history.list(user.id, query);
  }

  @Post()
  @ApiOperation({ summary: 'Record a view (upserts viewedAt)' })
  async record(@CurrentUser() user: AuthUser, @Body() dto: HadithIdDto) {
    return { data: await this.history.record(user.id, dto.hadithId) };
  }
}

@Module({
  imports: [HadithsModule],
  controllers: [ReadingHistoryController],
  providers: [ReadingHistoryService],
})
export class ReadingHistoryModule {}
