import { Module } from '@nestjs/common';
import { GraphQLServerModule } from '@/graphql/graphql.module';
import { EnumerationModule } from '@/graphql/enumeration/enumeration.module';

@Module({
  imports: [GraphQLServerModule, EnumerationModule],
})
export class AppModule {}
