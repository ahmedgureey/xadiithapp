import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { setupApp } from './setup-app';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  setupApp(app);
  const port = Number(app.get(ConfigService).get('PORT') ?? 3000);
  await app.listen(port, '0.0.0.0');
  Logger.log(`Xadiis API listening on port ${port} (prefix /api/v1, docs /api/docs)`, 'Bootstrap');
}

bootstrap().catch((err: unknown) => {
  // Env validation errors land here: fail fast with a clear message.
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
