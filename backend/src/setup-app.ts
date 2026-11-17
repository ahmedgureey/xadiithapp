import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { appVersion } from './common/utils/app-version';

export const API_PREFIX = 'api/v1';

/** Shared HTTP setup used by main.ts and the e2e tests. */
export function setupApp(app: INestApplication): void {
  const config = app.get(ConfigService);
  const express = app as NestExpressApplication;

  if (config.get<boolean>('TRUST_PROXY')) {
    // Behind Coolify's Traefik (one proxy hop) so req.ip is the real client IP.
    express.set('trust proxy', 1);
  }
  express.disable('x-powered-by');

  app.use(
    helmet({
      // Swagger UI needs inline scripts/styles.
      contentSecurityPolicy: false,
      crossOriginEmbedderPolicy: false,
    }),
  );

  const origins = String(config.get('CORS_ORIGINS') ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  if (origins.length > 0) {
    app.enableCors({
      origin: origins,
      methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      maxAge: 600,
    });
  }

  app.setGlobalPrefix(API_PREFIX);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());
  app.enableShutdownHooks();

  const doc = new DocumentBuilder()
    .setTitle('Xadiis App API')
    .setDescription(
      'Somali Hadith reading & memorization API. Success bodies are wrapped in `data`; lists add `meta`.',
    )
    .setVersion(appVersion())
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' })
    .build();
  const document = SwaggerModule.createDocument(app, doc);
  SwaggerModule.setup('api/docs', app, document, { jsonDocumentUrl: 'api/docs-json' });
}
