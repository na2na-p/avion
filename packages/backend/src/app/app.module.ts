import { Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { join } from 'path';

@Module({
  imports: [
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      // NOTE: 本番ではfalseに
      // playground: false,
      path: '/api',
      typePaths: [join(process.cwd(), '../graphql/dist/schema.graphql')],
      definitions: {
        path: join(process.cwd(), 'src/generated/types.ts'),
      },
    }),
  ],
})
export class AppModule {}
