export type Typename<
  T extends {
    __typename?: string;
  },
> = Lowercase<NonNullable<T['__typename']>>;
