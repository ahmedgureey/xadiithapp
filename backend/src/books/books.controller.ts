import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import { PaginationQueryDto } from '../common/pagination/pagination';
import { BooksService } from './books.service';

@ApiTags('Books')
@Controller('books')
export class BooksController {
  constructor(private readonly books: BooksService) {}

  @Get()
  @ApiOperation({ summary: 'List hadith books (sorted by sortOrder)' })
  list(@Query() query: PaginationQueryDto) {
    return this.books.list(query);
  }

  @Get(':id')
  @ApiParam({ name: 'id', description: 'Book UUID or slug (e.g. sahih-bukhari)' })
  @ApiOperation({ summary: 'Get a book by id or slug' })
  async get(@Param('id') id: string) {
    return { data: await this.books.get(id) };
  }

  @Get(':id/chapters')
  @ApiParam({ name: 'id', description: 'Book UUID or slug' })
  @ApiOperation({ summary: 'List chapters of a book (sorted by number)' })
  chapters(@Param('id') id: string, @Query() query: PaginationQueryDto) {
    return this.books.chapters(id, query);
  }
}
