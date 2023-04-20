import { Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { ApolloServerPluginLandingPageLocalDefault } from '@apollo/server/plugin/landingPage/default';
import { join } from 'path';

@Module({
  imports: [
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      path: '/api',
      typePaths: [join(process.cwd(), '../graphql/dist/schema.graphql')],
      definitions: {
        path: join(process.cwd(), 'src/generated/types.ts'),
        emitTypenameField: true,
        outputAs: 'class',
      },
      playground: false,
      // TODO: productionであればfalseになるように
      plugins: [ApolloServerPluginLandingPageLocalDefault()],
    }),
  ],
})
export class GraphQLServerModule {}
