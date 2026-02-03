-- Create databases for each service
-- This runs automatically on first PostgreSQL startup

-- Omni database
CREATE DATABASE omni;

-- Authentik database
CREATE DATABASE authentik;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE omni TO homelab;
GRANT ALL PRIVILEGES ON DATABASE authentik TO homelab;
