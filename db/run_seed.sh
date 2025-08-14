#!/bin/bash
set -e

SEED_ID="$1"
if [ -z "$SEED_ID" ]; then
    echo "Usage: $0 <seed_id>"
    exit 1
fi

BASE_DIR="$(dirname "$0")"
SEED_DIR="$BASE_DIR/seeds/$SEED_ID"
JSON_FILE="$SEED_DIR/${SEED_ID}.json"
CSV_FILE="$SEED_DIR/${SEED_ID}.csv"

if [ ! -f "$JSON_FILE" ] || [ ! -f "$CSV_FILE" ]; then
  echo "Seed files for $SEED_ID not found"
  exit 1
fi

# Extract table name from JSON manually without jq
TABLE=$(grep -o '"table" *: *"[^"]*"' "$JSON_FILE" | sed 's/.*"table" *: *"//;s/"$//')
if [ -z "$TABLE" ]; then
  echo "Could not find 'table' in $JSON_FILE"
  exit 1
fi

echo "🌱 Seeding table: $TABLE from $CSV_FILE"

# Create a temp staging table name
STAGING_TABLE="staging_${TABLE//./_}"

# Get header line from CSV
HEADER=$(head -n 1 "$CSV_FILE")

# Create staging table dynamically with text columns
psql -U postgres -d mydb -c "DROP TABLE IF EXISTS $STAGING_TABLE;"
psql -U postgres -d mydb -c "CREATE TABLE $STAGING_TABLE ($(echo $HEADER | sed 's/,/ TEXT,/g') TEXT);"

# Import CSV into staging table
psql -U postgres -d mydb -c "\COPY $STAGING_TABLE FROM '$CSV_FILE' CSV HEADER;"

# Insert into real table with geom computed from lat/lon
psql -U postgres -d mydb -c "
INSERT INTO $TABLE
(id, portfolio_name, project_name, site_name, owner_organization, service_organization,
 data_source, inspection_date, deficiencies, description, lat, lon, geom)
SELECT
  id::BIGINT,
  portfolio_name,
  project_name,
  site_name,
  owner_organization,
  service_organization,
  data_source,
  inspection_date::DATE,
  deficiencies,
  description,
  lat::DOUBLE PRECISION,
  lon::DOUBLE PRECISION,
  ST_Transform(ST_SetSRID(ST_MakePoint(lon::DOUBLE PRECISION, lat::DOUBLE PRECISION), 4326), 3857)
FROM $STAGING_TABLE;
"

# Drop staging table
psql -U postgres -d mydb -c "DROP TABLE $STAGING_TABLE;"

echo "✅ Seed $SEED_ID loaded into table '$TABLE'"
