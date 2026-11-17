import type { Profile, User } from '@prisma/client';

export type UserWithProfile = User & { profile: Profile | null };

export interface UserDto {
  id: string;
  email: string;
  role: User['role'];
  createdAt: Date;
  profile: { displayName: string; preferredLanguage: string };
}

export function toUserDto(user: UserWithProfile): UserDto {
  return {
    id: user.id,
    email: user.email,
    role: user.role,
    createdAt: user.createdAt,
    profile: {
      displayName: user.profile?.displayName ?? '',
      preferredLanguage: user.profile?.preferredLanguage ?? 'so',
    },
  };
}
