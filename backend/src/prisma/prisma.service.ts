import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit(): Promise<void> {
    // Connect lazily-but-early; a failed connection here should not crash the
    // process so /health can report "database: down".
    try {
      await this.$connect();
    } catch {
      // Prisma will retry connecting on the next query.
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
