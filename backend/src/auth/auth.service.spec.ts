import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import type { PrismaService } from '../prisma/prisma.service';
import { AuthService, generateRefreshToken, hashRefreshToken } from './auth.service';

const SECRET = 'unit-test-secret-unit-test-secret-0123456789';

interface TokenRow {
  id: string;
  userId: string;
  tokenHash: string;
  familyId: string;
  revokedAt: Date | null;
  replacedBy: string | null;
  expiresAt: Date;
}

function makePrismaMock() {
  const users: Record<string, unknown>[] = [];
  const tokens: TokenRow[] = [];
  let seq = 0;

  const matches = (row: TokenRow, where: Partial<TokenRow>) =>
    Object.entries(where).every(([k, v]) => (row as unknown as Record<string, unknown>)[k] === v);

  const prisma = {
    user: {
      findUnique: jest.fn(async ({ where }: { where: { email?: string; id?: string } }) => {
        return (
          users.find((u) => (where.email ? u.email === where.email : u.id === where.id)) ?? null
        );
      }),
      create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
        const profile = (data.profile as { create: Record<string, unknown> }).create;
        const user = {
          id: `user-${++seq}`,
          email: data.email,
          passwordHash: data.passwordHash,
          role: 'USER',
          createdAt: new Date(),
          updatedAt: new Date(),
          profile: { ...profile },
        };
        users.push(user);
        return user;
      }),
    },
    refreshToken: {
      findUnique: jest.fn(async ({ where }: { where: { tokenHash: string } }) => {
        return tokens.find((t) => t.tokenHash === where.tokenHash) ?? null;
      }),
      create: jest.fn(async ({ data }: { data: Omit<TokenRow, 'id' | 'revokedAt' | 'replacedBy'> }) => {
        const row: TokenRow = { id: `tok-${++seq}`, revokedAt: null, replacedBy: null, ...data };
        tokens.push(row);
        return row;
      }),
      update: jest.fn(async ({ where, data }: { where: { id: string }; data: Partial<TokenRow> }) => {
        const row = tokens.find((t) => t.id === where.id)!;
        Object.assign(row, data);
        return row;
      }),
      updateMany: jest.fn(
        async ({ where, data }: { where: Partial<TokenRow>; data: Partial<TokenRow> }) => {
          const rows = tokens.filter((t) => matches(t, where));
          rows.forEach((r) => Object.assign(r, data));
          return { count: rows.length };
        },
      ),
    },
  };
  return { prisma, users, tokens };
}

function makeService() {
  const mock = makePrismaMock();
  const config = new ConfigService({
    JWT_ACCESS_SECRET: SECRET,
    JWT_ACCESS_TTL: 900,
    JWT_REFRESH_TTL_DAYS: 30,
  });
  const jwt = new JwtService({});
  const service = new AuthService(mock.prisma as unknown as PrismaService, jwt, config);
  return { service, jwt, ...mock };
}

describe('AuthService', () => {
  it('hashes passwords with argon2id and verifies them', async () => {
    const { service } = makeService();
    const hash = await service.hashPassword('correct horse battery');
    expect(hash.startsWith('$argon2id$')).toBe(true);
    expect(hash).not.toContain('correct horse battery');
    await expect(service.verifyPassword(hash, 'correct horse battery')).resolves.toBe(true);
    await expect(service.verifyPassword(hash, 'wrong')).resolves.toBe(false);
  });

  it('refresh tokens are random base64url (>= 48 bytes) and stored only as SHA-256', async () => {
    const a = generateRefreshToken();
    const b = generateRefreshToken();
    expect(a).not.toEqual(b);
    expect(Buffer.from(a, 'base64url').length).toBeGreaterThanOrEqual(48);
    expect(hashRefreshToken(a)).toMatch(/^[0-9a-f]{64}$/);

    const { service, tokens } = makeService();
    const res = await service.register({
      email: 'A@Example.com ',
      password: 'password123',
      displayName: 'Ali',
    });
    expect(tokens).toHaveLength(1);
    expect(tokens[0].tokenHash).toBe(hashRefreshToken(res.refreshToken));
    expect(JSON.stringify(tokens)).not.toContain(res.refreshToken);
  });

  it('register normalises email, returns AuthResult and a valid HS256 access token', async () => {
    const { service, jwt } = makeService();
    const res = await service.register({
      email: '  User@Example.COM ',
      password: 'password123',
      displayName: 'Ayaan',
    });
    expect(res.user.email).toBe('user@example.com');
    expect(res.user.profile).toEqual({ displayName: 'Ayaan', preferredLanguage: 'so' });
    expect(res.accessTokenExpiresIn).toBe(900);
    const payload = await jwt.verifyAsync(res.accessToken, { secret: SECRET, algorithms: ['HS256'] });
    expect(payload.sub).toBe(res.user.id);
    expect(payload.role).toBe('USER');
  });

  it('register rejects duplicate email with 409', async () => {
    const { service } = makeService();
    await service.register({ email: 'dup@example.com', password: 'password123', displayName: 'X' });
    await expect(
      service.register({ email: 'DUP@example.com', password: 'password123', displayName: 'Y' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('login returns generic 401 for unknown email and wrong password', async () => {
    const { service } = makeService();
    await service.register({ email: 'x@example.com', password: 'password123', displayName: 'X' });
    await expect(service.login({ email: 'nobody@example.com', password: 'whatever1' })).rejects.toThrow(
      'Invalid email or password',
    );
    await expect(service.login({ email: 'x@example.com', password: 'wrongpass' })).rejects.toThrow(
      'Invalid email or password',
    );
    const ok = await service.login({ email: 'X@example.com', password: 'password123' });
    expect(ok.user.email).toBe('x@example.com');
  });

  it('refresh rotates: old token revoked, new token in same family', async () => {
    const { service, tokens } = makeService();
    const first = await service.register({
      email: 'r@example.com',
      password: 'password123',
      displayName: 'R',
    });
    const second = await service.refresh(first.refreshToken);
    expect(second.refreshToken).not.toBe(first.refreshToken);
    expect(tokens).toHaveLength(2);
    expect(tokens[0].revokedAt).toBeInstanceOf(Date);
    expect(tokens[0].replacedBy).toBe(tokens[1].id);
    expect(tokens[1].revokedAt).toBeNull();
    expect(tokens[1].familyId).toBe(tokens[0].familyId);
  });

  it('reuse of a revoked refresh token revokes the whole family', async () => {
    const { service, tokens } = makeService();
    const first = await service.register({
      email: 'reuse@example.com',
      password: 'password123',
      displayName: 'R',
    });
    const second = await service.refresh(first.refreshToken);
    await expect(service.refresh(first.refreshToken)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(tokens.every((t) => t.revokedAt !== null)).toBe(true);
    await expect(service.refresh(second.refreshToken)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects unknown and expired refresh tokens', async () => {
    const { service, tokens } = makeService();
    await expect(service.refresh('not-a-real-token')).rejects.toBeInstanceOf(UnauthorizedException);
    const res = await service.register({
      email: 'exp@example.com',
      password: 'password123',
      displayName: 'E',
    });
    tokens[0].expiresAt = new Date(Date.now() - 1000);
    await expect(service.refresh(res.refreshToken)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('logout revokes the token so it cannot be refreshed', async () => {
    const { service, tokens } = makeService();
    const res = await service.register({
      email: 'out@example.com',
      password: 'password123',
      displayName: 'O',
    });
    await service.logout(res.refreshToken);
    expect(tokens[0].revokedAt).toBeInstanceOf(Date);
    await expect(service.refresh(res.refreshToken)).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
