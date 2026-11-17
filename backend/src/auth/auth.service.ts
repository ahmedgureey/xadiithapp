import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { createHash, randomBytes, randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { toUserDto, UserDto, UserWithProfile } from '../users/user.mapper';
import { LoginDto, RegisterDto } from './dto/auth.dto';

export interface AuthResult {
  user: UserDto;
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
}

const INVALID_CREDENTIALS = 'Invalid email or password';
const INVALID_REFRESH = 'Invalid refresh token';

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

export function generateRefreshToken(): string {
  return randomBytes(48).toString('base64url');
}

@Injectable()
export class AuthService {
  private dummyHash: Promise<string> | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  hashPassword(password: string): Promise<string> {
    return argon2.hash(password, { type: argon2.argon2id });
  }

  verifyPassword(hash: string, password: string): Promise<boolean> {
    return argon2.verify(hash, password).catch(() => false);
  }

  async register(dto: RegisterDto): Promise<AuthResult> {
    const email = dto.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({ where: { email }, select: { id: true } });
    if (existing) throw new ConflictException('Email is already registered');

    const passwordHash = await this.hashPassword(dto.password);
    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        profile: { create: { displayName: dto.displayName.trim(), preferredLanguage: 'so' } },
        notificationSettings: { create: {} },
      },
      include: { profile: true },
    });
    return this.issueTokens(user);
  }

  async login(dto: LoginDto): Promise<AuthResult> {
    const email = dto.email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email }, include: { profile: true } });
    if (!user) {
      // Spend comparable time to avoid user-enumeration via timing.
      await this.verifyPassword(await this.getDummyHash(), dto.password);
      throw new UnauthorizedException(INVALID_CREDENTIALS);
    }
    const ok = await this.verifyPassword(user.passwordHash, dto.password);
    if (!ok) throw new UnauthorizedException(INVALID_CREDENTIALS);
    return this.issueTokens(user);
  }

  /**
   * Rotates a refresh token. Reuse of an already-revoked token revokes the
   * whole token family (all descendants), forcing re-login.
   */
  async refresh(rawToken: string): Promise<AuthResult> {
    const tokenHash = hashRefreshToken(rawToken);
    const existing = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });
    if (!existing) throw new UnauthorizedException(INVALID_REFRESH);

    if (existing.revokedAt) {
      await this.revokeFamily(existing.familyId);
      throw new UnauthorizedException(INVALID_REFRESH);
    }
    if (existing.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException(INVALID_REFRESH);
    }

    // Atomically claim the token; if another request already rotated it, treat as reuse.
    const claimed = await this.prisma.refreshToken.updateMany({
      where: { id: existing.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (claimed.count === 0) {
      await this.revokeFamily(existing.familyId);
      throw new UnauthorizedException(INVALID_REFRESH);
    }

    const user = await this.prisma.user.findUnique({
      where: { id: existing.userId },
      include: { profile: true },
    });
    if (!user) throw new UnauthorizedException(INVALID_REFRESH);

    const result = await this.issueTokens(user, existing.familyId, existing.id);
    return result;
  }

  async logout(rawToken: string): Promise<void> {
    const tokenHash = hashRefreshToken(rawToken);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async revokeFamily(familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issueTokens(
    user: UserWithProfile,
    familyId: string = randomUUID(),
    replacesTokenId?: string,
  ): Promise<AuthResult> {
    const accessTtl = Number(this.config.get('JWT_ACCESS_TTL') ?? 900);
    const refreshDays = Number(this.config.get('JWT_REFRESH_TTL_DAYS') ?? 30);

    const accessToken = await this.jwt.signAsync(
      { sub: user.id, role: user.role },
      {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: accessTtl,
        algorithm: 'HS256',
      },
    );

    const refreshToken = generateRefreshToken();
    const created = await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: hashRefreshToken(refreshToken),
        familyId,
        expiresAt: new Date(Date.now() + refreshDays * 24 * 60 * 60 * 1000),
      },
    });
    if (replacesTokenId) {
      await this.prisma.refreshToken.update({
        where: { id: replacesTokenId },
        data: { replacedBy: created.id },
      });
    }

    return {
      user: toUserDto(user),
      accessToken,
      refreshToken,
      accessTokenExpiresIn: accessTtl,
    };
  }

  private getDummyHash(): Promise<string> {
    if (!this.dummyHash) this.dummyHash = this.hashPassword(randomBytes(16).toString('hex'));
    return this.dummyHash;
  }
}
