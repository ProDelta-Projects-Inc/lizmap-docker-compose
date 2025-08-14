#!/bin/bash
set -e

# ------------------------------------------------------------
# Usage:
#   ./db/run_seed.sh <seed_id> [target_srid]
#
# Description:
#   Seeds a PostGIS table from a CSV and JSON definition in ./db/seeds/<seed_id>/.
#
# Required:
#   <seed_id>     The folder name inside ./db/seeds/ containing:
#                   - <seed_id>.csv : Data file
#                   - <seed_id>.json: Metadata file (must contain "table" key)
#
# Optional:
#   [target_srid] Override the target SRID for geometry transformation.
#
# SRID determination rules:
#   Input SRID:
#       1. "srid" key in JSON
#       2. Default: 4326 (WGS84)
#
#   Target SRID:
#       1. Command-line [target_srid]
#       2. "target_srid" key in JSON
#       3. Default: 3857 (Web Mercator)
#
# Notes:
#   - Requires a PostGIS-enabled database.
#   - Assumes CSV contains 'lat' and 'lon' columns.
#   - Geometry is computed in-memory; no temp geometry table is created.
# ------------------------------------------------------------

SEED_ID="$1"
TARGET_SRID_ARG="$2"

if [ -z "$SEED_ID" ]; then
  echo "Usage: $0 <seed_id> [target_srid]"
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

# --- Parse values from JSON manually ---
TABLE=$(grep -o '"table" *: *"[^"]*"' "$JSON_FILE" | sed 's/.*"table" *: *"//;s/"$//')
INPUT_SRID=$(grep -o '"srid" *: *[0-9]\+' "$JSON_FILE" | sed 's/.*: *//')
TARGET_SRID_JSON=$(grep -o '"target_srid" *: *[0-9]\+' "$JSON_FILE" | sed 's/.*: *//')

# Fallbacks
[ -z "$INPUT_SRID" ] && INPUT_SRID=4326
if [ -n "$TARGET_SRID_ARG" ]; then
  TARGET_SRID="$TARGET_SRID_ARG"
elif [ -n "$TARGET_SRID_JSON" ]; then
  TARGET_SRID="$TARGET_SRID_JSON"
else
  TARGET_SRID=3857
fi

if [ -z "$TABLE" ]; then
  echo "Could not find 'table' in $JSON_FILE"
  exit 1
fi

echo "Seeding table: $TABLE from $CSV_FILE"
echo "Input SRID: $INPUT_SRID → Target SRID: $TARGET_SRID"

# Create staging table name
STAGING_TABLE="staging_${TABLE//./_}"

# Get header from CSV
HEADER=$(head -n 1 "$CSV_FILE")

# Create staging table with TEXT columns
docker exec -i postgis-1 psql -U postgres -d lizmap -c "DROP TABLE IF EXISTS $STAGING_TABLE;"
docker exec -i postgis-1 psql -U postgres -d lizmap -c "CREATE TABLE $STAGING_TABLE ($(echo "$HEADER" | sed 's/,/ TEXT,/g') TEXT);"

# Import CSV into staging table
cat "$CSV_FILE" | docker exec -i postgis-1 psql -U postgres -d lizmap -c "\COPY $STAGING_TABLE FROM STDIN CSV HEADER;"

# Insert into real table
docker exec -i postgis-1 psql -U postgres -d lizmap -c "
INSERT INTO $TABLE
SELECT
  *,
  ST_Transform(
    ST_SetSRID(
      ST_MakePoint(lon::DOUBLE PRECISION, lat::DOUBLE PRECISION),
      $INPUT_SRID
    ),
    $TARGET_SRID
  ) AS geom
FROM $STAGING_TABLE;
"

# Drop staging table
docker exec -i postgis-1 psql -U postgres -d lizmap -c "DROP TABLE $STAGING_TABLE;"

echo "Seed $SEED_ID loaded into table '$TABLE'"
