-- Initialize Avion database
-- This script runs when PostgreSQL container is first created

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create schemas for each service
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS drops;
CREATE SCHEMA IF NOT EXISTS timeline;
CREATE SCHEMA IF NOT EXISTS activitypub;
CREATE SCHEMA IF NOT EXISTS notifications;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS search;
CREATE SCHEMA IF NOT EXISTS moderation;
CREATE SCHEMA IF NOT EXISTS community;
CREATE SCHEMA IF NOT EXISTS messages;

-- Grant permissions
GRANT ALL ON SCHEMA auth TO avion;
GRANT ALL ON SCHEMA users TO avion;
GRANT ALL ON SCHEMA drops TO avion;
GRANT ALL ON SCHEMA timeline TO avion;
GRANT ALL ON SCHEMA activitypub TO avion;
GRANT ALL ON SCHEMA notifications TO avion;
GRANT ALL ON SCHEMA media TO avion;
GRANT ALL ON SCHEMA search TO avion;
GRANT ALL ON SCHEMA moderation TO avion;
GRANT ALL ON SCHEMA community TO avion;
GRANT ALL ON SCHEMA messages TO avion;