#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const DB_NAME = 'lizmap';
const DB_USER = 'lizmap';
const POSTGIS_CONTAINER = 'postgis-1';
const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

function runCommand(command, input = null) {
  try {
    return execSync(command, {
      stdio: input ? ['pipe', 'pipe', 'pipe'] : 'inherit',
      input: input ? input : undefined,
      encoding: 'utf8',
    }).trim();
  } catch (err) {
    console.error('Command failed:', command);
    console.error(err.stdout);
    console.error(err.stderr);
    process.exit(1);
  }
}

function getMigrationFiles() {
  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort()
    .map(f => path.join(MIGRATIONS_DIR, f));
}

function getMigrationVersion(filePath) {
  return path.basename(filePath).split('_')[0];
}

function migrationAlreadyApplied(version) {
  const cmd = `docker exec -i ${POSTGIS_CONTAINER} psql -t -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1 FROM lizmap.schema_migrations WHERE version = '${version}';"`;
  const result = runCommand(cmd);
  return result !== '';
}

function applyMigration(filePath, version) {
  console.log(`Applying migration ${version}`);

  const content = fs.readFileSync(filePath, 'utf8');

  // Extract SQL between -- UP and -- DOWN
  const upMatch = content.match(/-- UP([\s\S]*?)-- DOWN/);
  if (!upMatch) {
    console.error(`Migration file ${filePath} missing -- UP/-- DOWN sections`);
    process.exit(1);
  }

  const upSQL = upMatch[1].trim();

  // Run inside PostGIS container
  runCommand(`docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME}`, upSQL);

  // Record migration
  const insertCmd = `docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "INSERT INTO lizmap.schema_migrations (version) VALUES ('${version}');"`;
  runCommand(insertCmd);
}

function main() {
  const files = getMigrationFiles();

  files.forEach(file => {
    const version = getMigrationVersion(file);

    if (migrationAlreadyApplied(version)) {
      console.log(`Skipping migration ${version} (already applied)`);
    } else {
      applyMigration(file, version);
    }
  });

  console.log('All migrations applied.');
}

main();
