#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const POSTGIS_CONTAINER = 'postgis-1';
const DB_NAME = 'lizmap';
const DB_USER = 'postgres'; // matches your script
const BASE_DIR = __dirname;

function runCommand(command, input = null) {
  try {
    return execSync(command, {
      stdio: input ? ['pipe', 'inherit', 'pipe'] : 'inherit',
      input: input ? input : undefined,
      encoding: 'utf8',
    });
  } catch (err) {
    console.error('Command failed:', command);
    console.error(err.stdout);
    console.error(err.stderr);
    process.exit(1);
  }
}

function main() {
  const SEED_ID = process.argv[2];
  const TARGET_SRID_ARG = process.argv[3];

  if (!SEED_ID) {
    console.error('Usage: node run_seed.js <seed_id> [target_srid]');
    process.exit(1);
  }

  const SEED_DIR = path.join(BASE_DIR, 'seeds', SEED_ID);
  const JSON_FILE = path.join(SEED_DIR, `${SEED_ID}.json`);
  const CSV_FILE = path.join(SEED_DIR, `${SEED_ID}.csv`);

  if (!fs.existsSync(JSON_FILE) || !fs.existsSync(CSV_FILE)) {
    console.error(`Seed files for ${SEED_ID} not found`);
    process.exit(1);
  }

  // Read JSON metadata
  const meta = JSON.parse(fs.readFileSync(JSON_FILE, 'utf8'));
  const TABLE = meta.table;
  const INPUT_SRID = meta.srid || 4326;
  const TARGET_SRID = TARGET_SRID_ARG || meta.target_srid || 3857;

  if (!TABLE) {
    console.error(`Could not find 'table' in ${JSON_FILE}`);
    process.exit(1);
  }

  console.log(`Seeding table: ${TABLE} from ${CSV_FILE}`);
  console.log(`Input SRID: ${INPUT_SRID} → Target SRID: ${TARGET_SRID}`);

  // Create staging table name
  const STAGING_TABLE = `staging_${TABLE.replace('.', '_')}`;

  // Drop and recreate staging table
  runCommand(
    `docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "DROP TABLE IF EXISTS ${STAGING_TABLE};"`
  );
  runCommand(
    `docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "
      CREATE TABLE ${STAGING_TABLE} (LIKE ${TABLE} INCLUDING ALL INCLUDING DEFAULTS);
      ALTER TABLE ${STAGING_TABLE} DROP COLUMN geom;
    "`
  );

  // Import CSV into staging table
  const csvContent = fs.readFileSync(CSV_FILE);
  runCommand(
    `docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "\\COPY ${STAGING_TABLE} FROM STDIN CSV HEADER;"`,
    csvContent
  );

  // Insert into real table with geometry
  runCommand(
    `docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "
      INSERT INTO ${TABLE}
      SELECT
        *,
        ST_Transform(
          ST_SetSRID(
            ST_MakePoint(lon::DOUBLE PRECISION, lat::DOUBLE PRECISION),
            ${INPUT_SRID}
          ),
          ${TARGET_SRID}
        ) AS geom
      FROM ${STAGING_TABLE};
    "`
  );

  // Drop staging table
  runCommand(
    `docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "DROP TABLE ${STAGING_TABLE};"`
  );

  console.log(`Seed ${SEED_ID} loaded into table '${TABLE}'`);
}

main();
