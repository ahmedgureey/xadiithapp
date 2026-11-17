import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOperation, ApiTags, ApiTooManyRequestsResponse } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { LoginDto, RefreshTokenDto, RegisterDto } from './dto/auth.dto';

/** Per-IP limit for credential endpoints; read at request time (AUTH_THROTTLE_LIMIT, default 5/min). */
const authThrottle = {
  default: {
    limit: () => Number(process.env.AUTH_THROTTLE_LIMIT) || 5,
    ttl: 60_000,
  },
};

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @Throttle(authThrottle)
  @ApiTooManyRequestsResponse()
  @ApiOperation({ summary: 'Register a new account (201 AuthResult, 409 if email exists)' })
  async register(@Body() dto: RegisterDto) {
    return { data: await this.auth.register(dto) };
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle(authThrottle)
  @ApiTooManyRequestsResponse()
  @ApiOperation({ summary: 'Log in (200 AuthResult, 401 on invalid credentials)' })
  async login(@Body() dto: LoginDto) {
    return { data: await this.auth.login(dto) };
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @Throttle(authThrottle)
  @ApiTooManyRequestsResponse()
  @ApiOperation({
    summary:
      'Rotate refresh token (old one is revoked). Reusing a revoked token revokes the whole family.',
  })
  async refresh(@Body() dto: RefreshTokenDto) {
    return { data: await this.auth.refresh(dto.refreshToken) };
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Revoke a refresh token (always 204)' })
  async logout(@Body() dto: RefreshTokenDto): Promise<void> {
    await this.auth.logout(dto.refreshToken);
  }
}
