import { createParamDecorator, ExecutionContext, SetMetadata } from '@nestjs/common';
import type { UserRole } from '@prisma/client';
import type { Request } from 'express';
import type { AuthUser } from './auth.types';

export const ROLES_KEY = 'roles';

/** Restricts a route to the given roles. ADMIN is always allowed. */
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);

export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext) => {
  const req = ctx.switchToHttp().getRequest<Request & { user?: AuthUser }>();
  return req.user;
});
