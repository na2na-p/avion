import { Module } from '@nestjs/common';
import { GraphQLServerModule } from '@/graphql/graphql.module';
import { EnumerationModule } from '@/enumeration/enumeration.module';

@Module({
  imports: [GraphQLServerModule, EnumerationModule],
})
export class AppModule {}
