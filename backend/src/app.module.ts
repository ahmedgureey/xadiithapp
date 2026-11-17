import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AdminModule } from './admin/admin.module';
import { AuthModule } from './auth/auth.module';
import { BookmarksModule } from './bookmarks/bookmarks.module';
import { BooksModule } from './books/books.module';
import { CategoriesModule } from './categories/categories.module';
import { AuthCommonModule } from './common/auth/auth-common.module';
import { validateEnv } from './config/env.validation';
import { HadithsModule } from './hadiths/hadiths.module';
import { HealthModule } from './health/health.module';
import { MemorizationModule } from './memorization/memorization.module';
import { PrismaModule } from './prisma/prisma.module';
import { ReadingHistoryModule } from './reading-history/reading-history.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnv,
    }),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        throttlers: [
          {
            name: 'default',
            ttl: 60_000,
            limit: Number(config.get('THROTTLE_LIMIT') ?? 120),
          },
        ],
      }),
    }),
    PrismaModule,
    AuthCommonModule,
    HealthModule,
    BooksModule,
    CategoriesModule,
    HadithsModule,
    AuthModule,
    UsersModule,
    BookmarksModule,
    MemorizationModule,
    ReadingHistoryModule,
    AdminModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
