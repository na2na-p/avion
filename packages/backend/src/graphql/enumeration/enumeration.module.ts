import { Module } from '@nestjs/common';
import { EnumerationService } from './enumeration.service';
import { EnumerationResolver } from './enumeration.resolver';

@Module({
  providers: [EnumerationResolver, EnumerationService],
})
export class EnumerationModule {}
