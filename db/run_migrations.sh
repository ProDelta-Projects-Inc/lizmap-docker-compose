#!/bin/bash
set -e

DB_NAME=lizmap
DB_USER=lizmap
POSTGIS_CONTAINER=postgis-1
MIGRATIONS_DIR=db/migrations

# Loop through all migration files in order
for file in $(ls $MIGRATIONS_DIR/*.sql | sort); do
    version=$(basename "$file" | cut -d'_' -f1)

    # Check if migration already applied
    already_applied=$(docker exec -i $POSTGIS_CONTAINER psql -t -U $DB_USER -d $DB_NAME -c \
        "SELECT 1 FROM lizmap.schema_migrations WHERE version = '$version';" | xargs)

    if [ -z "$already_applied" ]; then
        echo "Applying migration $version"

        # Extract UP section
        up_sql=$(sed -n '/-- UP/,/-- DOWN/p' "$file" | sed '/-- UP/d;/-- DOWN/d')

        # Run inside PostGIS container
        echo "$up_sql" | docker exec -i $POSTGIS_CONTAINER psql -U $DB_USER -d $DB_NAME

        # Record migration
        docker exec -i $POSTGIS_CONTAINER psql -U $DB_USER -d $DB_NAME -c \
            "INSERT INTO lizmap.schema_migrations (version) VALUES ('$version');"
    else
        echo "Skipping migration $version (already applied)"
    fi
done

echo "All migrations applied."
