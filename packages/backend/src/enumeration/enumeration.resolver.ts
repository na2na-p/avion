import { Query, Resolver } from '@nestjs/graphql';
import { EnumerationService } from './enumeration.service';
import { Enumeration } from '@/generated/types';

@Resolver('Enumeration')
export class EnumerationResolver {
  constructor(private readonly enumerationService: EnumerationService) {}

  @Query(
    'enumeration' satisfies Lowercase<NonNullable<Enumeration['__typename']>>
  )
  enumeration() {
    return this.enumerationService.enumeration();
  }
}
