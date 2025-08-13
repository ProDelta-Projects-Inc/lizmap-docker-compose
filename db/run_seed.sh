#!/bin/bash
set -e

# Usage: ./db/run_seed.sh 001
VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: $0 <seed_version>"
  exit 1
fi

BASE_DIR="$(dirname "$0")"
SEED_DIR="$BASE_DIR/seeds"
SEED_PATH="$SEED_DIR/$VERSION"

if [ ! -d "$SEED_PATH" ]; then
  echo "Seed version '$VERSION' not found."
  exit 1
fi

JSON_FILE="$SEED_PATH/$VERSION.json"
CSV_FILE="$SEED_PATH/$VERSION.csv"

if [ ! -f "$JSON_FILE" ]; then
  echo "JSON file not found: $JSON_FILE"
  exit 1
fi
if [ ! -f "$CSV_FILE" ]; then
  echo "CSV file not found: $CSV_FILE"
  exit 1
fi

# Extract table name using sed (works everywhere)
TABLE=$(sed -n 's/.*"table"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$JSON_FILE")
if [ -z "$TABLE" ]; then
  echo "Could not find 'table' in $JSON_FILE"
  exit 1
fi

echo "Seeding table: $TABLE from $CSV_FILE"

# Database connection settings
DB_NAME=${DB_NAME:-lizmap}
DB_USER=${DB_USER:-postgres}
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}

# Import CSV into the specified table
psql "host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USER" <<EOF
\COPY $TABLE FROM '$CSV_FILE' WITH CSV HEADER;
EOF

echo "✅ Seed $VERSION loaded into table '$TABLE'"
