import { Controller, Get, HttpStatus, Module, Res } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Response } from 'express';
import { appVersion } from '../common/utils/app-version';
import { PrismaService } from '../prisma/prisma.service';

@ApiTags('Health')
@SkipThrottle()
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @ApiOperation({ summary: 'Liveness + database check (503 when the database is down)' })
  async check(@Res({ passthrough: true }) res: Response) {
    let up = false;
    let timer: NodeJS.Timeout | undefined;
    try {
      await Promise.race([
        this.prisma.$queryRaw`SELECT 1`,
        new Promise((_, reject) => {
          timer = setTimeout(() => reject(new Error('timeout')), 3000);
        }),
      ]);
      up = true;
    } catch {
      up = false;
    } finally {
      if (timer) clearTimeout(timer);
    }
    if (!up) res.status(HttpStatus.SERVICE_UNAVAILABLE);
    return {
      status: up ? 'ok' : 'error',
      database: up ? 'up' : 'down',
      version: appVersion(),
      timestamp: new Date().toISOString(),
    };
  }
}

@Module({ controllers: [HealthController] })
export class HealthModule {}
