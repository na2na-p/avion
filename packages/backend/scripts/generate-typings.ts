import { GraphQLDefinitionsFactory } from '@nestjs/graphql';
import { join } from 'path';
import yargs from 'yargs';

const argv = yargs
  .options({
    watch: {
      alias: 'w',
      type: 'boolean',
      description: 'watch mode',
      default: false,
    },
  })
  .help()
  .parseSync();

const definitionsFactory = new GraphQLDefinitionsFactory();
definitionsFactory.generate({
  typePaths: [join(process.cwd(), '../graphql/dist/schema.graphql')],
  path: join(process.cwd(), './src/generated/types.ts'),
  emitTypenameField: true,
  watch: argv.watch,
});
