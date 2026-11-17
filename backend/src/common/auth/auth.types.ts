import type { UserRole } from '@prisma/client';

export interface AuthUser {
  id: string;
  role: UserRole;
}

export interface AccessTokenPayload {
  sub: string;
  role: UserRole;
}
