import { Query, Resolver } from '@nestjs/graphql';
import { EnumerationService } from './enumeration.service';
import { Enumeration } from '@/generated/types';
import { Typename } from '@/types/TypeName';

@Resolver('Enumeration')
export class EnumerationResolver {
  constructor(private readonly enumerationService: EnumerationService) {}

  @Query('enumeration' satisfies Typename<Enumeration>)
  enumeration() {
    return this.enumerationService.enumeration();
  }
}
