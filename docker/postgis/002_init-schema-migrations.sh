#!/bin/bash
set -e

# Connect to the Lizmap database as the Lizmap user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_LIZMAP_USER" --dbname "$POSTGRES_LIZMAP_DB" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS lizmap AUTHORIZATION "$POSTGRES_LIZMAP_USER";

    CREATE TABLE IF NOT EXISTS lizmap.schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMP DEFAULT NOW()
    );
EOSQL
