import { Test, TestingModule } from '@nestjs/testing';
import { EnumerationResolver } from './enumeration.resolver';
import { EnumerationService } from './enumeration.service';

describe('EnumerationResolver', () => {
  let resolver: EnumerationResolver;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [EnumerationResolver, EnumerationService],
    }).compile();

    resolver = module.get<EnumerationResolver>(EnumerationResolver);
  });

  it('should be defined', () => {
    expect(resolver).toBeDefined();
  });
});
