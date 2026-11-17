import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  ValidateNested,
} from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const LANGS = ['so', 'en', 'ar'];

export class TranslationInputDto {
  @ApiProperty({ enum: LANGS, example: 'so' })
  @IsIn(LANGS)
  language: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(20000)
  text: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  translator?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  source?: string;
}

export class GradingInputDto {
  @ApiProperty({ example: 'Sahih' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  grade: string;

  @ApiPropertyOptional({ description: 'Scholar who graded the hadith' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  gradedBy?: string;

  @ApiPropertyOptional({ description: 'Citation for the grading (required by at least one grading to publish)' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  source?: string;
}

export class ExplanationInputDto {
  @ApiProperty({ enum: LANGS, example: 'so' })
  @IsIn(LANGS)
  language: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(50000)
  text: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  author?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  source?: string;
}

export class CreateHadithDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  bookId: string;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  chapterId?: string;

  @ApiProperty({ example: '52a' })
  @Transform(trim)
  @IsString()
  @Matches(/^[0-9A-Za-z\-/.]{1,20}$/, { message: 'hadithNumber must be 1-20 chars of [0-9A-Za-z-/.]' })
  hadithNumber: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(50000)
  arabicText: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(300)
  narrator?: string;

  @ApiPropertyOptional({ description: 'Required before the hadith can be published' })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  sourceReference?: string;

  @ApiPropertyOptional({ type: TranslationInputDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => TranslationInputDto)
  translation?: TranslationInputDto;

  @ApiPropertyOptional({ type: GradingInputDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => GradingInputDto)
  grading?: GradingInputDto;

  @ApiPropertyOptional({ type: ExplanationInputDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ExplanationInputDto)
  explanation?: ExplanationInputDto;

  @ApiPropertyOptional({ type: [String], format: 'uuid' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('all', { each: true })
  categoryIds?: string[];
}

/** All fields optional. translation/grading/explanation, when given, are ADDED (as DRAFT content). */
export class UpdateHadithDto {
  @ApiPropertyOptional({ format: 'uuid', nullable: true })
  @IsOptional()
  @IsUUID()
  chapterId?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @Matches(/^[0-9A-Za-z\-/.]{1,20}$/, { message: 'hadithNumber must be 1-20 chars of [0-9A-Za-z-/.]' })
  hadithNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(50000)
  arabicText?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(300)
  narrator?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  sourceReference?: string;

  @ApiPropertyOptional({ type: TranslationInputDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => TranslationInputDto)
  translation?: TranslationInputDto;

  @ApiPropertyOptional({ type: GradingInputDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => GradingInputDto)
  grading?: GradingInputDto;

  @ApiPropertyOptional({ type: ExplanationInputDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => ExplanationInputDto)
  explanation?: ExplanationInputDto;

  @ApiPropertyOptional({ type: [String], format: 'uuid', description: 'Replaces the category set' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('all', { each: true })
  categoryIds?: string[];
}

export class ReviewDecisionDto {
  @ApiProperty({ enum: ['APPROVED', 'REJECTED'] })
  @IsIn(['APPROVED', 'REJECTED'])
  decision: 'APPROVED' | 'REJECTED';

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(2000)
  notes?: string;
}
