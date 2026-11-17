import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { AuthUser } from '../common/auth/auth.types';
import { CurrentUser, Roles } from '../common/auth/decorators';
import { JwtAuthGuard } from '../common/auth/jwt-auth.guard';
import { RolesGuard } from '../common/auth/roles.guard';
import { PaginationQueryDto } from '../common/pagination/pagination';
import { AdminService } from './admin.service';
import { CreateHadithDto, ReviewDecisionDto, UpdateHadithDto } from './dto/admin.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Post('hadiths')
  @Roles('EDITOR', 'REVIEWER')
  @ApiOperation({ summary: 'Create a hadith as DRAFT (EDITOR/REVIEWER/ADMIN)' })
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateHadithDto) {
    return { data: await this.admin.createHadith(user, dto) };
  }

  @Get('hadiths/:id')
  @Roles('EDITOR', 'REVIEWER')
  @ApiOperation({ summary: 'Get a hadith in any status (admin view)' })
  async get(@Param('id', new ParseUUIDPipe()) id: string) {
    return { data: await this.admin.getHadith(id) };
  }

  @Patch('hadiths/:id')
  @Roles('EDITOR', 'REVIEWER')
  @ApiOperation({
    summary:
      'Edit a hadith (EDITOR: DRAFT only). Writes content_change_history with before/after JSON.',
  })
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateHadithDto,
  ) {
    return { data: await this.admin.updateHadith(user, id, dto) };
  }

  @Post('hadiths/:id/submit')
  @HttpCode(HttpStatus.OK)
  @Roles('EDITOR', 'REVIEWER')
  @ApiOperation({ summary: 'Submit a DRAFT hadith for review (-> PENDING_REVIEW)' })
  async submit(@CurrentUser() user: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) {
    return { data: await this.admin.submitHadith(user, id) };
  }

  @Get('pending-reviews')
  @Roles('REVIEWER')
  @ApiOperation({ summary: 'List pending content reviews (REVIEWER/ADMIN)' })
  pending(@Query() query: PaginationQueryDto) {
    return this.admin.pendingReviews(query);
  }

  @Post('content-reviews/:id/decision')
  @HttpCode(HttpStatus.OK)
  @Roles('REVIEWER')
  @ApiOperation({
    summary:
      'Approve (publishes hadith + its translations/explanations) or reject. Requires sourceReference and a grading with a source to approve.',
  })
  async decide(
    @CurrentUser() user: AuthUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: ReviewDecisionDto,
  ) {
    return { data: await this.admin.decide(user, id, dto) };
  }
}
