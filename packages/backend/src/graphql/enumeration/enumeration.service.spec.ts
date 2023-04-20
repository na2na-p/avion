import { Test, TestingModule } from '@nestjs/testing';
import { EnumerationService } from './enumeration.service';

describe('EnumerationService', () => {
  let service: EnumerationService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [EnumerationService],
    }).compile();

    service = module.get<EnumerationService>(EnumerationService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
