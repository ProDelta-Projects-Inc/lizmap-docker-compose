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

# Extract table name from JSON
TABLE=$(grep -o '"table" *: *"[^"]*"' "$JSON_FILE" | sed 's/.*"table" *: *"//;s/"$//')
if [ -z "$TABLE" ]; then
  echo "Could not find 'table' in $JSON_FILE"
  exit 1
fi

echo "Seeding table: $TABLE from $CSV_FILE"

# Staging table name
STAGING_TABLE="staging_${TABLE//./_}"

# Extract header from CSV
HEADER=$(head -n 1 "$CSV_FILE")
HEADER_CLEAN=$(echo "$HEADER" | tr -d '\r')

# Create staging table with all TEXT columns
psql -U postgres -d mydb -c "DROP TABLE IF EXISTS $STAGING_TABLE;"
psql -U postgres -d mydb -c "CREATE TABLE $STAGING_TABLE ($(echo $HEADER_CLEAN | sed 's/,/ TEXT,/g') TEXT);"

# Import CSV into staging table
psql -U postgres -d mydb -c "\COPY $STAGING_TABLE FROM '$CSV_FILE' CSV HEADER;"

# Build insert column list and select expression list
IFS=',' read -ra COLS <<< "$HEADER_CLEAN"
INSERT_COLS=()
SELECT_COLS=()
HAS_LAT=false
HAS_LON=false

for col in "${COLS[@]}"; do
    col_trim=$(echo "$col" | xargs) # remove spaces
    INSERT_COLS+=("$col_trim")
    SELECT_COLS+=("$col_trim")

    [[ "$col_trim" == "lat" ]] && HAS_LAT=true
    [[ "$col_trim" == "lon" ]] && HAS_LON=true
done

# Add geom column if lat/lon present
if $HAS_LAT && $HAS_LON; then
    INSERT_COLS+=("geom")
    SELECT_COLS+=("ST_Transform(ST_SetSRID(ST_MakePoint(lon::DOUBLE PRECISION, lat::DOUBLE PRECISION), 4326), 3857)")
fi

INSERT_COLS_STR=$(IFS=','; echo "${INSERT_COLS[*]}")
SELECT_COLS_STR=$(IFS=','; echo "${SELECT_COLS[*]}")

# Insert into main table
psql -U postgres -d mydb -c "
INSERT INTO $TABLE ($INSERT_COLS_STR)
SELECT $SELECT_COLS_STR FROM $STAGING_TABLE;
"

# Drop staging table
psql -U postgres -d mydb -c "DROP TABLE $STAGING_TABLE;"

echo "Seed $SEED_ID loaded into table '$TABLE'"
