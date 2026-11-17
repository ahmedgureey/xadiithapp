import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { normalizeArabic } from '../common/arabic/arabic-normalize';
import type { AuthUser } from '../common/auth/auth.types';
import { paginate, PaginationQueryDto, toPageParams } from '../common/pagination/pagination';
import { hadithNumberSortKey } from '../common/utils/hadith-number';
import { adminHadithInclude, AdminHadithRecord, toAdminHadithDto } from '../hadiths/hadith.mapper';
import { PrismaService } from '../prisma/prisma.service';
import { CreateHadithDto, ReviewDecisionDto, UpdateHadithDto } from './dto/admin.dto';

export const ENTITY_HADITH = 'hadith';

type Tx = Prisma.TransactionClient;

function snapshot(h: AdminHadithRecord): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(toAdminHadithDto(h))) as Prisma.InputJsonValue;
}

function emptyToNull(v: string | undefined | null): string | null | undefined {
  if (v === undefined) return undefined;
  if (v === null) return null;
  return v.trim() === '' ? null : v.trim();
}

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async createHadith(user: AuthUser, dto: CreateHadithDto) {
    await this.assertRefs(dto.bookId, dto.chapterId ?? null, dto.categoryIds);
    const created = await this.prisma.$transaction(async (tx) => {
      const exists = await tx.hadith.findUnique({
        where: { bookId_hadithNumber: { bookId: dto.bookId, hadithNumber: dto.hadithNumber } },
        select: { id: true },
      });
      if (exists) throw new ConflictException('A hadith with this number already exists in the book');

      const h = await tx.hadith.create({
        data: {
          bookId: dto.bookId,
          chapterId: dto.chapterId ?? null,
          hadithNumber: dto.hadithNumber,
          hadithNumberSort: hadithNumberSortKey(dto.hadithNumber),
          arabicText: dto.arabicText,
          arabicTextNormalized: normalizeArabic(dto.arabicText),
          narrator: emptyToNull(dto.narrator) ?? null,
          sourceReference: emptyToNull(dto.sourceReference) ?? null,
          status: 'DRAFT',
          createdById: user.id,
          translations: dto.translation
            ? { create: { ...dto.translation, status: 'DRAFT' } }
            : undefined,
          gradings: dto.grading ? { create: { ...dto.grading } } : undefined,
          explanations: dto.explanation
            ? { create: { ...dto.explanation, status: 'DRAFT' } }
            : undefined,
          categories: dto.categoryIds?.length
            ? { create: [...new Set(dto.categoryIds)].map((categoryId) => ({ categoryId })) }
            : undefined,
        },
        include: adminHadithInclude,
      });
      await this.history(tx, h.id, 'CREATE', user.id, null, snapshot(h));
      return h;
    });
    return toAdminHadithDto(created);
  }

  async getHadith(id: string) {
    const h = await this.prisma.hadith.findUnique({ where: { id }, include: adminHadithInclude });
    if (!h) throw new NotFoundException('Hadith not found');
    return toAdminHadithDto(h);
  }

  async updateHadith(user: AuthUser, id: string, dto: UpdateHadithDto) {
    const updated = await this.prisma.$transaction(async (tx) => {
      const before = await tx.hadith.findUnique({ where: { id }, include: adminHadithInclude });
      if (!before) throw new NotFoundException('Hadith not found');
      if (user.role === 'EDITOR' && before.status !== 'DRAFT') {
        throw new ConflictException('Editors can only edit hadiths in DRAFT status');
      }
      if (dto.chapterId !== undefined && dto.chapterId !== null) {
        await this.assertChapter(tx, before.bookId, dto.chapterId);
      }
      if (dto.categoryIds) await this.assertCategories(tx, dto.categoryIds);
      if (dto.hadithNumber && dto.hadithNumber !== before.hadithNumber) {
        const clash = await tx.hadith.findUnique({
          where: { bookId_hadithNumber: { bookId: before.bookId, hadithNumber: dto.hadithNumber } },
          select: { id: true },
        });
        if (clash) throw new ConflictException('A hadith with this number already exists in the book');
      }

      const data: Prisma.HadithUncheckedUpdateInput = {};
      if (dto.chapterId !== undefined) data.chapterId = dto.chapterId;
      if (dto.hadithNumber !== undefined) {
        data.hadithNumber = dto.hadithNumber;
        data.hadithNumberSort = hadithNumberSortKey(dto.hadithNumber);
      }
      if (dto.arabicText !== undefined) {
        data.arabicText = dto.arabicText;
        data.arabicTextNormalized = normalizeArabic(dto.arabicText);
      }
      if (dto.narrator !== undefined) data.narrator = emptyToNull(dto.narrator);
      if (dto.sourceReference !== undefined) data.sourceReference = emptyToNull(dto.sourceReference);
      if (dto.translation) {
        data.translations = { create: { ...dto.translation, status: 'DRAFT' } };
      }
      if (dto.grading) data.gradings = { create: { ...dto.grading } };
      if (dto.explanation) {
        data.explanations = { create: { ...dto.explanation, status: 'DRAFT' } };
      }
      if (dto.categoryIds) {
        data.categories = {
          deleteMany: {},
          create: [...new Set(dto.categoryIds)].map((categoryId) => ({ categoryId })),
        };
      }

      const after = await tx.hadith.update({ where: { id }, data, include: adminHadithInclude });
      await this.history(tx, id, 'UPDATE', user.id, snapshot(before), snapshot(after));
      return after;
    });
    return toAdminHadithDto(updated);
  }

  async submitHadith(user: AuthUser, id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.hadith.findUnique({ where: { id }, include: adminHadithInclude });
      if (!before) throw new NotFoundException('Hadith not found');
      if (before.status !== 'DRAFT') {
        throw new ConflictException(`Only DRAFT hadiths can be submitted (current: ${before.status})`);
      }
      await tx.hadithTranslation.updateMany({
        where: { hadithId: id, status: 'DRAFT' },
        data: { status: 'PENDING_REVIEW' },
      });
      await tx.hadithExplanation.updateMany({
        where: { hadithId: id, status: 'DRAFT' },
        data: { status: 'PENDING_REVIEW' },
      });
      const after = await tx.hadith.update({
        where: { id },
        data: { status: 'PENDING_REVIEW' },
        include: adminHadithInclude,
      });
      const review = await tx.contentReview.create({
        data: { entityType: ENTITY_HADITH, entityId: id, status: 'PENDING', submittedById: user.id },
      });
      await this.history(tx, id, 'SUBMIT', user.id, snapshot(before), snapshot(after));
      return { ...this.toReviewDto(review), hadith: toAdminHadithDto(after) };
    });
  }

  async pendingReviews(query: PaginationQueryDto) {
    const params = toPageParams(query);
    const where: Prisma.ContentReviewWhereInput = { status: 'PENDING' };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.contentReview.count({ where }),
      this.prisma.contentReview.findMany({
        where,
        include: { submittedBy: { select: { id: true, email: true } } },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        skip: params.skip,
        take: params.take,
      }),
    ]);
    const hadithIds = rows.filter((r) => r.entityType === ENTITY_HADITH).map((r) => r.entityId);
    const hadiths = await this.prisma.hadith.findMany({
      where: { id: { in: hadithIds } },
      include: adminHadithInclude,
    });
    const byId = new Map(hadiths.map((h) => [h.id, toAdminHadithDto(h)]));
    return paginate(
      rows.map((r) => ({
        ...this.toReviewDto(r),
        submittedBy: r.submittedBy,
        hadith: byId.get(r.entityId) ?? null,
      })),
      total,
      params,
    );
  }

  async decide(user: AuthUser, reviewId: string, dto: ReviewDecisionDto) {
    return this.prisma.$transaction(async (tx) => {
      const review = await tx.contentReview.findUnique({ where: { id: reviewId } });
      if (!review) throw new NotFoundException('Review not found');
      if (review.status !== 'PENDING') {
        throw new ConflictException('Review has already been decided');
      }
      if (review.submittedById === user.id && user.role !== 'ADMIN') {
        throw new ForbiddenException('You cannot review your own submission');
      }
      if (review.entityType !== ENTITY_HADITH) {
        throw new BadRequestException(`Unsupported entity type: ${review.entityType}`);
      }
      const before = await tx.hadith.findUnique({
        where: { id: review.entityId },
        include: adminHadithInclude,
      });
      if (!before) throw new NotFoundException('Hadith not found');
      if (before.status !== 'PENDING_REVIEW') {
        throw new ConflictException(`Hadith is not pending review (current: ${before.status})`);
      }

      if (dto.decision === 'APPROVED') {
        const problems: string[] = [];
        if (!before.sourceReference || before.sourceReference.trim() === '') {
          problems.push('sourceReference is required to publish');
        }
        if (!before.gradings.some((g) => g.source && g.source.trim() !== '')) {
          problems.push('at least one grading with a source is required to publish');
        }
        if (problems.length > 0) throw new UnprocessableEntityException(problems);

        await tx.hadithTranslation.updateMany({
          where: { hadithId: before.id, status: { in: ['DRAFT', 'PENDING_REVIEW'] } },
          data: { status: 'PUBLISHED' },
        });
        await tx.hadithExplanation.updateMany({
          where: { hadithId: before.id, status: { in: ['DRAFT', 'PENDING_REVIEW'] } },
          data: { status: 'PUBLISHED' },
        });
      } else {
        await tx.hadithTranslation.updateMany({
          where: { hadithId: before.id, status: 'PENDING_REVIEW' },
          data: { status: 'DRAFT' },
        });
        await tx.hadithExplanation.updateMany({
          where: { hadithId: before.id, status: 'PENDING_REVIEW' },
          data: { status: 'DRAFT' },
        });
      }

      const after = await tx.hadith.update({
        where: { id: before.id },
        data:
          dto.decision === 'APPROVED'
            ? { status: 'PUBLISHED', publishedAt: new Date() }
            : { status: 'DRAFT' },
        include: adminHadithInclude,
      });
      const decided = await tx.contentReview.update({
        where: { id: review.id },
        data: {
          status: dto.decision,
          reviewedById: user.id,
          reviewedAt: new Date(),
          notes: dto.notes ?? null,
        },
      });
      await this.history(
        tx,
        before.id,
        dto.decision === 'APPROVED' ? 'APPROVE' : 'REJECT',
        user.id,
        snapshot(before),
        snapshot(after),
      );
      return { ...this.toReviewDto(decided), hadith: toAdminHadithDto(after) };
    });
  }

  private toReviewDto(r: {
    id: string;
    entityType: string;
    entityId: string;
    status: string;
    submittedById: string;
    reviewedById: string | null;
    notes: string | null;
    reviewedAt: Date | null;
    createdAt: Date;
  }) {
    return {
      id: r.id,
      entityType: r.entityType,
      entityId: r.entityId,
      status: r.status,
      submittedById: r.submittedById,
      reviewedById: r.reviewedById,
      notes: r.notes,
      reviewedAt: r.reviewedAt,
      createdAt: r.createdAt,
    };
  }

  private async history(
    tx: Tx,
    entityId: string,
    action: string,
    userId: string,
    before: Prisma.InputJsonValue | null,
    after: Prisma.InputJsonValue | null,
  ) {
    await tx.contentChangeHistory.create({
      data: {
        entityType: ENTITY_HADITH,
        entityId,
        action,
        changedById: userId,
        before: before ?? Prisma.DbNull,
        after: after ?? Prisma.DbNull,
      },
    });
  }

  private async assertRefs(bookId: string, chapterId: string | null, categoryIds?: string[]) {
    const book = await this.prisma.hadithBook.count({ where: { id: bookId } });
    if (!book) throw new BadRequestException('bookId does not exist');
    if (chapterId) await this.assertChapter(this.prisma, bookId, chapterId);
    if (categoryIds?.length) await this.assertCategories(this.prisma, categoryIds);
  }

  private async assertChapter(tx: Tx | PrismaService, bookId: string, chapterId: string) {
    const ok = await tx.hadithChapter.count({ where: { id: chapterId, bookId } });
    if (!ok) throw new BadRequestException('chapterId does not exist in this book');
  }

  private async assertCategories(tx: Tx | PrismaService, ids: string[]) {
    const unique = [...new Set(ids)];
    const found = await tx.category.count({ where: { id: { in: unique } } });
    if (found !== unique.length) throw new BadRequestException('One or more categoryIds do not exist');
  }
}
