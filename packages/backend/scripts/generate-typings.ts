import { GraphQLDefinitionsFactory } from '@nestjs/graphql';
import { join } from 'path';

const definitionsFactory = new GraphQLDefinitionsFactory();
definitionsFactory.generate({
  typePaths: [join(process.cwd(), '../graphql/dist/schema.graphql')],
  path: join(process.cwd(), './src/generated/types.ts'),
  emitTypenameField: true,
  watch: true,
});
