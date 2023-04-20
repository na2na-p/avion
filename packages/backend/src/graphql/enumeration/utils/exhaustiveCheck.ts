import type { Choice } from '@/types/Choices';
import { ElementOf } from '@/types/ElementOf';

export type IsExhaustive<TKeys, TChoices extends ReadonlyArray<Choice>> =
  | Exclude<TKeys, ElementOf<TChoices>['id']>
  | Exclude<ElementOf<TChoices>['id'], TKeys> extends never
  ? true
  :
      | Exclude<TKeys, ElementOf<TChoices>['id']>
      | Exclude<ElementOf<TChoices>['id'], TKeys>;
