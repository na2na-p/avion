-- Initialize databases for Avion services
-- This script runs when PostgreSQL container is first created

-- Create database for each service (if using separate databases)
-- Uncomment if you want separate databases per service
-- CREATE DATABASE avion_auth;
-- CREATE DATABASE avion_user;
-- CREATE DATABASE avion_drop;
-- CREATE DATABASE avion_timeline;
-- CREATE DATABASE avion_media;
-- CREATE DATABASE avion_notification;
-- CREATE DATABASE avion_search;
-- CREATE DATABASE avion_moderation;
-- CREATE DATABASE avion_community;

-- Create schemas for each service (using single database with schemas)
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS drops;
CREATE SCHEMA IF NOT EXISTS timeline;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SCHEMA IF NOT EXISTS search;
CREATE SCHEMA IF NOT EXISTS moderation;
CREATE SCHEMA IF NOT EXISTS community;
CREATE SCHEMA IF NOT EXISTS activitypub;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For text search
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For composite indexes
CREATE EXTENSION IF NOT EXISTS "btree_gist"; -- For exclusion constraints

-- Set default search path
ALTER DATABASE avion SET search_path TO public, auth, users, drops, timeline, media, notification, search, moderation, community, activitypub;

-- Grant privileges to the avion user
GRANT ALL PRIVILEGES ON SCHEMA auth TO avion;
GRANT ALL PRIVILEGES ON SCHEMA users TO avion;
GRANT ALL PRIVILEGES ON SCHEMA drops TO avion;
GRANT ALL PRIVILEGES ON SCHEMA timeline TO avion;
GRANT ALL PRIVILEGES ON SCHEMA media TO avion;
GRANT ALL PRIVILEGES ON SCHEMA notification TO avion;
GRANT ALL PRIVILEGES ON SCHEMA search TO avion;
GRANT ALL PRIVILEGES ON SCHEMA moderation TO avion;
GRANT ALL PRIVILEGES ON SCHEMA community TO avion;
GRANT ALL PRIVILEGES ON SCHEMA activitypub TO avion;

-- Set statement timeout for development (5 seconds)
ALTER DATABASE avion SET statement_timeout = '5s';

-- Set connection limits
ALTER DATABASE avion CONNECTION LIMIT 200;

-- Create read-only user for analytics (optional)
-- CREATE USER avion_readonly WITH PASSWORD 'readonly_password';
-- GRANT CONNECT ON DATABASE avion TO avion_readonly;
-- GRANT USAGE ON SCHEMA public, auth, users, drops, timeline TO avion_readonly;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public, auth, users, drops, timeline TO avion_readonly;
