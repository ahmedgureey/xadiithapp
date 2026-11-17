import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { HadithListQueryDto, SearchQueryDto } from './dto/hadith-query.dto';
import { HadithsService } from './hadiths.service';

@ApiTags('Hadiths')
@Controller('hadiths')
export class HadithsController {
  constructor(private readonly hadiths: HadithsService) {}

  @Get()
  @ApiOperation({ summary: 'List published hadiths (natural order)' })
  list(@Query() query: HadithListQueryDto) {
    return this.hadiths.list(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get one published hadith' })
  async get(@Param('id', new ParseUUIDPipe()) id: string) {
    return { data: await this.hadiths.getPublished(id) };
  }
}

@ApiTags('Search')
@Controller('search')
export class SearchController {
  constructor(private readonly hadiths: HadithsService) {}

  @Get()
  @ApiOperation({
    summary:
      'Search published hadiths by Arabic text (diacritics-insensitive), Somali translation, narrator, book name, or exact hadith number',
  })
  search(@Query() query: SearchQueryDto) {
    return this.hadiths.search(query);
  }
}

@ApiTags('Hadiths')
@Controller('hadith-of-the-day')
export class HadithOfTheDayController {
  constructor(private readonly hadiths: HadithsService) {}

  @Get()
  @ApiOperation({ summary: 'Deterministic hadith for the current UTC date (null if none published)' })
  async get() {
    return { data: await this.hadiths.hadithOfTheDay() };
  }
}
