import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class HadithIdDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  hadithId: string;
}
