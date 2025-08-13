#!/bin/bash
set -e

SEED_NUM="$1"

if [ -z "$SEED_NUM" ]; then
    echo "Usage: ./db/run_seed.sh <seed_number>"
    exit 1
fi

SEED_DIR="db/seeds/$SEED_NUM"
JSON_FILE="$SEED_DIR/${SEED_NUM}.json"
CSV_FILE="$SEED_DIR/${SEED_NUM}.csv"

if [ ! -f "$JSON_FILE" ]; then
    echo "Seed JSON file not found: $JSON_FILE"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo "Seed CSV file not found: $CSV_FILE"
    exit 1
fi

# Extract table name and columns from JSON
TABLE=$(jq -r '.table' "$JSON_FILE")
COLUMNS=$(jq -r '.columns | join(",")' "$JSON_FILE")

echo "Seeding table: $TABLE"
echo "Columns: $COLUMNS"
echo "From CSV: $CSV_FILE"

# Run COPY into Postgres inside the container
docker exec -i postgis-1 psql -U lizmap -d lizmap -c "\
    COPY $TABLE ($COLUMNS)
    FROM STDIN
    WITH (FORMAT csv, HEADER true, QUOTE '\"');" < "$CSV_FILE"

echo "✅ Seed $SEED_NUM completed."
