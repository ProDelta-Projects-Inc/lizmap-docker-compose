#!/bin/bash
set -e

DB_NAME=lizmap
DB_USER=lizmap
POSTGIS_CONTAINER=postgis-1
MIGRATIONS_DIR=db/migrations

# Get last applied migration
last_version=$(docker exec -i $POSTGIS_CONTAINER psql -t -U $DB_USER -d $DB_NAME -c \
    "SELECT version FROM lizmap.schema_migrations ORDER BY version DESC LIMIT 1;" | xargs)

if [ -z "$last_version" ]; then
    echo "No migrations to rollback"
    exit 0
fi

file=$(ls $MIGRATIONS_DIR/${last_version}_*.sql)
echo "Rolling back migration $last_version"

down_sql=$(sed -n '/-- DOWN/,$p' "$file" | sed '/-- DOWN/d')

echo "$down_sql" | docker exec -i $POSTGIS_CONTAINER psql -U $DB_USER -d $DB_NAME

# Remove from schema_migrations
docker exec -i $POSTGIS_CONTAINER psql -U $DB_USER -d $DB_NAME -c \
    "DELETE FROM lizmap.schema_migrations WHERE version='$last_version';"

echo "Migration $last_version rolled back."
