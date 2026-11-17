import { plainToInstance, Transform } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
  validateSync,
} from 'class-validator';

const toBool = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? ['1', 'true', 'yes', 'on'].includes(value.toLowerCase()) : value;

export class EnvironmentVariables {
  @IsIn(['development', 'production', 'test'])
  @IsOptional()
  NODE_ENV: 'development' | 'production' | 'test' = 'development';

  @Transform(({ value }) => (value === undefined || value === '' ? 3000 : Number(value)))
  @IsInt()
  @Min(1)
  @Max(65535)
  PORT: number = 3000;

  @IsString()
  @IsNotEmpty({ message: 'DATABASE_URL is required' })
  DATABASE_URL: string;

  @IsString()
  @MinLength(32, { message: 'JWT_ACCESS_SECRET must be at least 32 characters' })
  JWT_ACCESS_SECRET: string;

  @Transform(({ value }) => (value === undefined || value === '' ? 900 : Number(value)))
  @IsInt()
  @Min(60)
  @Max(86400)
  JWT_ACCESS_TTL: number = 900;

  @Transform(({ value }) => (value === undefined || value === '' ? 30 : Number(value)))
  @IsInt()
  @Min(1)
  @Max(365)
  JWT_REFRESH_TTL_DAYS: number = 30;

  @IsString()
  @IsOptional()
  CORS_ORIGINS: string = '';

  @Transform(toBool)
  @IsBoolean()
  @IsOptional()
  TRUST_PROXY: boolean = false;

  /** Requests per minute per IP for general endpoints. */
  @Transform(({ value }) => (value === undefined || value === '' ? 120 : Number(value)))
  @IsInt()
  @Min(1)
  THROTTLE_LIMIT: number = 120;

  /** Requests per minute per IP for /auth/login, /auth/register, /auth/refresh. */
  @Transform(({ value }) => (value === undefined || value === '' ? 5 : Number(value)))
  @IsInt()
  @Min(1)
  AUTH_THROTTLE_LIMIT: number = 5;
}

export function validateEnv(config: Record<string, unknown>): EnvironmentVariables {
  const validated = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: false,
    exposeDefaultValues: true,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length > 0) {
    const details = errors
      .map((e) => `${e.property}: ${Object.values(e.constraints ?? {}).join(', ')}`)
      .join('\n  ');
    throw new Error(`Invalid environment configuration:\n  ${details}`);
  }
  return validated;
}
