import { Module } from '@nestjs/common';

import { EnumerationResolver } from './enumeration.resolver';
import { EnumerationService } from './enumeration.service';

@Module({
  providers: [EnumerationResolver, EnumerationService],
})
export class EnumerationModule {}
