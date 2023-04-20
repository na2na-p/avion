import { join } from 'path';

import { ApolloServerPluginLandingPageLocalDefault } from '@apollo/server/plugin/landingPage/default';
import { EnumerationModule } from '@graphql/enumeration/enumeration.module';
import type { ApolloDriverConfig } from '@nestjs/apollo';
import { ApolloDriver } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';

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
      installSubscriptionHandlers: true,
      playground: false,
      // TODO: productionであればfalseになるように
      plugins: [ApolloServerPluginLandingPageLocalDefault()],
    }),
    EnumerationModule,
  ],
})
export class GraphQLServerModule {}
