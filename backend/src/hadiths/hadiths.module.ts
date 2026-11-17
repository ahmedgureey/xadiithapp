import { Module } from '@nestjs/common';
import { HadithOfTheDayController, HadithsController, SearchController } from './hadiths.controller';
import { HadithsService } from './hadiths.service';

@Module({
  controllers: [HadithsController, SearchController, HadithOfTheDayController],
  providers: [HadithsService],
  exports: [HadithsService],
})
export class HadithsModule {}
