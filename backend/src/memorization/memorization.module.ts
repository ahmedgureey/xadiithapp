import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Injectable,
  Module,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { MemorizationStatus, Prisma } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';
import type { AuthUser } from '../common/auth/auth.types';
import { CurrentUser } from '../common/auth/decorators';
import { JwtAuthGuard } from '../common/auth/jwt-auth.guard';
import { HadithIdDto } from '../common/dto/hadith-id.dto';
import { paginate, PaginationQueryDto, toPageParams } from '../common/pagination/pagination';
import { publicHadithInclude, toHadithDto } from '../hadiths/hadith.mapper';
import { HadithsModule } from '../hadiths/hadiths.module';
import { HadithsService } from '../hadiths/hadiths.service';
import { PrismaService } from '../prisma/prisma.service';
import { applySm2 } from './sm2';

export class MemorizationQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: MemorizationStatus })
  @IsOptional()
  @IsEnum(MemorizationStatus)
  status?: MemorizationStatus;

  @ApiPropertyOptional({ description: 'true = only items with nextReviewAt <= now' })
  @IsOptional()
  @Transform(({ value }) => (value === 'true' || value === true ? true : value === 'false' || value === false ? false : value))
  @IsBoolean()
  due?: boolean;
}

export class UpdateMemorizationDto {
  @ApiPropertyOptional({ minimum: 0, maximum: 5, description: 'SM-2 recall quality (0-5)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(5)
  quality?: number;

  @ApiPropertyOptional({ enum: MemorizationStatus, description: 'Set status directly' })
  @IsOptional()
  @IsEnum(MemorizationStatus)
  status?: MemorizationStatus;
}

const include = { hadith: { include: publicHadithInclude } } satisfies Prisma.MemorizationProgressInclude;
type Record_ = Prisma.MemorizationProgressGetPayload<{ include: typeof include }>;

function toDto(m: Record_) {
  return {
    id: m.id,
    hadithId: m.hadithId,
    status: m.status,
    repetitions: m.repetitions,
    easeFactor: m.easeFactor,
    intervalDays: m.intervalDays,
    nextReviewAt: m.nextReviewAt,
    lastReviewedAt: m.lastReviewedAt,
    createdAt: m.createdAt,
    hadith: toHadithDto(m.hadith),
  };
}

@Injectable()
export class MemorizationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly hadiths: HadithsService,
  ) {}

  async list(userId: string, query: MemorizationQueryDto) {
    const params = toPageParams(query);
    const where: Prisma.MemorizationProgressWhereInput = {
      userId,
      hadith: { status: 'PUBLISHED' },
    };
    if (query.status) where.status = query.status;
    if (query.due) where.nextReviewAt = { lte: new Date() };
    const orderBy: Prisma.MemorizationProgressOrderByWithRelationInput[] = query.due
      ? [{ nextReviewAt: 'asc' }, { id: 'asc' }]
      : [{ createdAt: 'desc' }, { id: 'asc' }];
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.memorizationProgress.count({ where }),
      this.prisma.memorizationProgress.findMany({
        where,
        include,
        orderBy,
        skip: params.skip,
        take: params.take,
      }),
    ]);
    return paginate(rows.map(toDto), total, params);
  }

  async add(userId: string, hadithId: string) {
    await this.hadiths.assertPublished(hadithId);
    const m = await this.prisma.memorizationProgress.upsert({
      where: { userId_hadithId: { userId, hadithId } },
      create: { userId, hadithId, status: 'NEW', nextReviewAt: new Date() },
      update: {},
      include,
    });
    return toDto(m);
  }

  async update(userId: string, id: string, dto: UpdateMemorizationDto) {
    const hasQuality = dto.quality !== undefined;
    const hasStatus = dto.status !== undefined;
    if (hasQuality === hasStatus) {
      throw new BadRequestException('Provide exactly one of "quality" or "status"');
    }
    const existing = await this.findOwned(userId, id);

    let data: Prisma.MemorizationProgressUpdateInput;
    if (hasQuality) {
      const r = applySm2(existing, dto.quality as number);
      data = {
        repetitions: r.repetitions,
        easeFactor: r.easeFactor,
        intervalDays: r.intervalDays,
        status: r.status,
        nextReviewAt: r.nextReviewAt,
        lastReviewedAt: r.lastReviewedAt,
      };
    } else {
      data = { status: dto.status };
    }
    const m = await this.prisma.memorizationProgress.update({ where: { id }, data, include });
    return toDto(m);
  }

  async remove(userId: string, id: string): Promise<void> {
    await this.findOwned(userId, id);
    await this.prisma.memorizationProgress.delete({ where: { id } });
  }

  private async findOwned(userId: string, id: string) {
    const m = await this.prisma.memorizationProgress.findFirst({ where: { id, userId } });
    if (!m) throw new NotFoundException('Memorization record not found');
    return m;
  }
}

@ApiTags('Memorization')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('memorization')
export class MemorizationController {
  constructor(private readonly memorization: MemorizationService) {}

  @Get()
  @ApiOperation({ summary: 'List memorization progress (?status=, ?due=true)' })
  list(@CurrentUser() user: AuthUser, @Query() query: MemorizationQueryDto) {
    return this.memorization.list(user.id, query);
  }

  @Post()
  @ApiOperation({ summary: 'Start memorizing a published hadith (idempotent)' })
  async add(@CurrentUser() user: AuthUser, @Body() dto: HadithIdDto) {
    return { data: await this.memorization.add(user.id, dto.hadithId) };
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Record a review ({ quality: 0..5 }, SM-2) or set { status } directly' })
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateMemorizationDto,
  ) {
    return { data: await this.memorization.update(user.id, id, dto) };
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a memorization record' })
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    await this.memorization.remove(user.id, id);
  }
}

@Module({
  imports: [HadithsModule],
  controllers: [MemorizationController],
  providers: [MemorizationService],
})
export class MemorizationModule {}
