import { Module } from '@nestjs/common';

import { GraphQLServerModule } from '@/graphql/graphql.module';

@Module({
  imports: [GraphQLServerModule],
})
export class AppModule {}
