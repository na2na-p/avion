import { Query, Resolver } from '@nestjs/graphql';

import type { Enumeration } from '@/generated/types';
import type { Typename } from '@/types/Typename';

import { EnumerationService } from './enumeration.service';

@Resolver('Enumeration')
export class EnumerationResolver {
  constructor(private readonly enumerationService: EnumerationService) {}

  @Query('enumeration' satisfies Typename<Enumeration>)
  enumeration() {
    return this.enumerationService.enumeration();
  }
}
