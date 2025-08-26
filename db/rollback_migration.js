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

function getLastAppliedMigration() {
  const cmd = `docker exec -i ${POSTGIS_CONTAINER} psql -t -U ${DB_USER} -d ${DB_NAME} -c "SELECT version FROM lizmap.schema_migrations ORDER BY version DESC LIMIT 1;"`;
  const result = runCommand(cmd);
  return result === '' ? null : result;
}

function getMigrationFile(version) {
  const files = fs.readdirSync(MIGRATIONS_DIR);
  const file = files.find(f => f.startsWith(`${version}_`) && f.endsWith('.sql'));
  return file ? path.join(MIGRATIONS_DIR, file) : null;
}

function rollbackMigration(filePath, version) {
  console.log(`Rolling back migration ${version}`);

  const content = fs.readFileSync(filePath, 'utf8');

  // Extract SQL after -- DOWN
  const downMatch = content.match(/-- DOWN([\s\S]*)$/);
  if (!downMatch) {
    console.error(`Migration file ${filePath} missing -- DOWN section`);
    process.exit(1);
  }

  const downSQL = downMatch[1].trim();

  // Run rollback inside PostGIS container
  runCommand(`docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME}`, downSQL);

  // Remove migration record
  const deleteCmd = `docker exec -i ${POSTGIS_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} -c "DELETE FROM lizmap.schema_migrations WHERE version='${version}';"`;
  runCommand(deleteCmd);

  console.log(`Migration ${version} rolled back.`);
}

function main() {
  const lastVersion = getLastAppliedMigration();

  if (!lastVersion) {
    console.log('No migrations to rollback');
    return;
  }

  const filePath = getMigrationFile(lastVersion);
  if (!filePath) {
    console.error(`Migration file for version ${lastVersion} not found`);
    process.exit(1);
  }

  rollbackMigration(filePath, lastVersion);
}

main();
