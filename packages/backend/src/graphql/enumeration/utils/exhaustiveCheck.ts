import type { Choice } from '@/types/Choices';
import type { ElementOf } from '@/types/ElementOf';

/**
 * enumを用いるChoices型の要素が全て列挙されているかをチェックする型
 */
export type IsExhaustive<TKeys, TChoices extends ReadonlyArray<Choice>> =
  | Exclude<TKeys, ElementOf<TChoices>['id']>
  | Exclude<ElementOf<TChoices>['id'], TKeys> extends never
  ? true
  :
      | Exclude<TKeys, ElementOf<TChoices>['id']>
      | Exclude<ElementOf<TChoices>['id'], TKeys>;
