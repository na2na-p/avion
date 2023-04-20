import { Injectable } from '@nestjs/common';

import type { Enumeration } from '@/generated/types';

import {
  baseRoleTypes,
  mediaExtensionTypes,
  postScopes,
  timelineTypes,
} from './parts';

@Injectable()
export class EnumerationService {
  enumeration(): Enumeration {
    // nameを言語に応じて変えられるようにしたい
    return {
      postScopes,
      timelineTypes,
      baseRoleTypes,
      mediaExtensionTypes,
    };
  }
}
