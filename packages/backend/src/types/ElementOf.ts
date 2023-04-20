/**
 * 配列あるいはイテレータ中の1要素の型を取り出す型
 */
export type ElementOf<T> = T extends ReadonlyArray<infer E>
  ? E
  : T extends Iterable<infer E>
  ? E
  : never;
