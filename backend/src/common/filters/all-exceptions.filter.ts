import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';
import { STATUS_CODES } from 'http';

export interface ErrorBody {
  statusCode: number;
  error: string;
  message: string | string[];
  path: string;
  timestamp: string;
}

/**
 * Produces every error as:
 * { statusCode, error, message, path, timestamp }
 * Request bodies are never logged (they may contain passwords or tokens).
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const response = exception.getResponse();
      if (typeof response === 'string') {
        message = response;
      } else if (response && typeof response === 'object') {
        const m = (response as { message?: unknown }).message;
        if (typeof m === 'string' || Array.isArray(m)) {
          message = m as string | string[];
        } else {
          message = exception.message;
        }
      }
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        status = HttpStatus.CONFLICT;
        message = 'Resource already exists';
      } else if (exception.code === 'P2025') {
        status = HttpStatus.NOT_FOUND;
        message = 'Resource not found';
      } else if (exception.code === 'P2003') {
        status = HttpStatus.BAD_REQUEST;
        message = 'Related resource does not exist';
      } else if (['P1001', 'P1002', 'P1008', 'P1017', 'P2024'].includes(exception.code)) {
        status = HttpStatus.SERVICE_UNAVAILABLE;
        message = 'Database unavailable';
        this.logger.error(`Database unavailable (${exception.code}) on ${req.method} ${req.path}`);
      } else {
        this.logger.error(`Prisma error ${exception.code} on ${req.method} ${req.path}`);
      }
    } else if (exception instanceof Prisma.PrismaClientInitializationError) {
      status = HttpStatus.SERVICE_UNAVAILABLE;
      message = 'Database unavailable';
      this.logger.error(`Database unavailable on ${req.method} ${req.path}`);
    } else {
      const err = exception as Error;
      this.logger.error(`Unhandled error on ${req.method} ${req.path}: ${err?.message}`, err?.stack);
    }

    const body: ErrorBody = {
      statusCode: status,
      error: STATUS_CODES[status] ?? 'Error',
      message,
      path: req.originalUrl?.split('?')[0] ?? req.url,
      timestamp: new Date().toISOString(),
    };
    res.status(status).json(body);
  }
}
