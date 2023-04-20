export type Choice<T = string> = {
  id: T;
  name: string;
};

export type Choices<T = string> = ReadonlyArray<Choice<T>>;
