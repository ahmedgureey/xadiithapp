import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Injectable,
  Module,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
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
export class BookmarksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly hadiths: HadithsService,
  ) {}

  async list(userId: string, query: PaginationQueryDto) {
    const params = toPageParams(query);
    const where = { userId, hadith: { status: 'PUBLISHED' as const } };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.bookmark.count({ where }),
      this.prisma.bookmark.findMany({
        where,
        include,
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: params.skip,
        take: params.take,
      }),
    ]);
    return paginate(
      rows.map((b) => ({
        id: b.id,
        hadithId: b.hadithId,
        createdAt: b.createdAt,
        hadith: toHadithDto(b.hadith),
      })),
      total,
      params,
    );
  }

  async add(userId: string, hadithId: string) {
    await this.hadiths.assertPublished(hadithId);
    const b = await this.prisma.bookmark.upsert({
      where: { userId_hadithId: { userId, hadithId } },
      create: { userId, hadithId },
      update: {},
      include,
    });
    return { id: b.id, hadithId: b.hadithId, createdAt: b.createdAt, hadith: toHadithDto(b.hadith) };
  }

  async remove(userId: string, hadithId: string): Promise<void> {
    await this.prisma.bookmark.deleteMany({ where: { userId, hadithId } });
  }
}

@ApiTags('Bookmarks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('bookmarks')
export class BookmarksController {
  constructor(private readonly bookmarks: BookmarksService) {}

  @Get()
  @ApiOperation({ summary: "List the current user's bookmarks (newest first)" })
  list(@CurrentUser() user: AuthUser, @Query() query: PaginationQueryDto) {
    return this.bookmarks.list(user.id, query);
  }

  @Post()
  @ApiOperation({ summary: 'Bookmark a published hadith (idempotent; 404 if not published)' })
  async add(@CurrentUser() user: AuthUser, @Body() dto: HadithIdDto) {
    return { data: await this.bookmarks.add(user.id, dto.hadithId) };
  }

  @Delete(':hadithId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiParam({
    name: 'hadithId',
    description: 'NOTE: this is the HADITH id, not the bookmark id. Idempotent (204 even if absent).',
  })
  @ApiOperation({ summary: 'Remove the bookmark for a hadith' })
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('hadithId', new ParseUUIDPipe()) hadithId: string,
  ): Promise<void> {
    await this.bookmarks.remove(user.id, hadithId);
  }
}

@Module({
  imports: [HadithsModule],
  controllers: [BookmarksController],
  providers: [BookmarksService],
})
export class BookmarksModule {}
