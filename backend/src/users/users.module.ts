import {
  Body,
  Controller,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Patch,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, IsString, Length, Matches } from 'class-validator';
import type { AuthUser } from '../common/auth/auth.types';
import { CurrentUser } from '../common/auth/decorators';
import { JwtAuthGuard } from '../common/auth/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { toUserDto } from './user.mapper';

export class UpdateMeDto {
  @ApiPropertyOptional({ minLength: 1, maxLength: 80 })
  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @Length(1, 80)
  displayName?: string;

  @ApiPropertyOptional({ enum: ['so', 'en'] })
  @IsOptional()
  @IsIn(['so', 'en'])
  preferredLanguage?: 'so' | 'en';
}

export class NotificationSettingsDto {
  @ApiProperty()
  @IsBoolean()
  dailyHadith: boolean;

  @ApiProperty()
  @IsBoolean()
  reviewReminders: boolean;

  @ApiProperty({ example: '08:00', description: '24h time HH:mm' })
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'reminderTime must be in HH:mm format' })
  reminderTime: string;
}

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return toUserDto(user);
  }

  async updateMe(userId: string, dto: UpdateMeDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new NotFoundException('User not found');
    await this.prisma.profile.upsert({
      where: { userId },
      create: {
        userId,
        displayName: dto.displayName ?? user.email.split('@')[0].slice(0, 80),
        preferredLanguage: dto.preferredLanguage ?? 'so',
      },
      update: {
        ...(dto.displayName !== undefined ? { displayName: dto.displayName } : {}),
        ...(dto.preferredLanguage !== undefined ? { preferredLanguage: dto.preferredLanguage } : {}),
      },
    });
    return this.getMe(userId);
  }

  async getNotificationSettings(userId: string) {
    const s = await this.prisma.userNotificationSettings.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
    return { dailyHadith: s.dailyHadith, reviewReminders: s.reviewReminders, reminderTime: s.reminderTime };
  }

  async putNotificationSettings(userId: string, dto: NotificationSettingsDto) {
    const data = {
      dailyHadith: dto.dailyHadith,
      reviewReminders: dto.reviewReminders,
      reminderTime: dto.reminderTime,
    };
    const s = await this.prisma.userNotificationSettings.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
    });
    return { dailyHadith: s.dailyHadith, reviewReminders: s.reviewReminders, reminderTime: s.reminderTime };
  }
}

@ApiTags('Me')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('me')
export class MeController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @ApiOperation({ summary: 'Current user' })
  async me(@CurrentUser() user: AuthUser) {
    return { data: await this.users.getMe(user.id) };
  }

  @Patch()
  @ApiOperation({ summary: 'Update display name / preferred language' })
  async update(@CurrentUser() user: AuthUser, @Body() dto: UpdateMeDto) {
    return { data: await this.users.updateMe(user.id, dto) };
  }

  @Get('notification-settings')
  @ApiOperation({ summary: 'Get notification settings' })
  async getSettings(@CurrentUser() user: AuthUser) {
    return { data: await this.users.getNotificationSettings(user.id) };
  }

  @Put('notification-settings')
  @ApiOperation({ summary: 'Replace notification settings' })
  async putSettings(@CurrentUser() user: AuthUser, @Body() dto: NotificationSettingsDto) {
    return { data: await this.users.putNotificationSettings(user.id, dto) };
  }
}

@Module({
  controllers: [MeController],
  providers: [UsersService],
})
export class UsersModule {}
