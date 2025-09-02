#!/usr/bin/env node
const { Client } = require("pg");

async function main() {
  // Environment variables (make sure they’re set in Docker or your shell)
  const {
    POSTGRES_USER,
    POSTGRES_PASSWORD,
    POSTGRES_DB,
    POSTGRES_LIZMAP_USER,
    POSTGRES_LIZMAP_PASSWORD,
    POSTGRES_LIZMAP_DB
  } = process.env;

  if (!POSTGRES_USER || !POSTGRES_DB || !POSTGRES_LIZMAP_USER || !POSTGRES_LIZMAP_PASSWORD || !POSTGRES_LIZMAP_DB) {
    console.error("❌ Missing required environment variables.");
    process.exit(1);
  }

  // Connect to main Postgres DB
  const adminClient = new Client({
    user: POSTGRES_USER,
    password: POSTGRES_PASSWORD,
    database: POSTGRES_DB,
    host: process.env.PGHOST || "localhost",
    port: process.env.PGPORT || 5432,
  });

  try {
    await adminClient.connect();

    console.log("⚙️ Creating Lizmap role and database...");

    // Create role + database
    await adminClient.query(`CREATE ROLE "${POSTGRES_LIZMAP_USER}" WITH NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN;`);
    await adminClient.query(`ALTER ROLE "${POSTGRES_LIZMAP_USER}" WITH PASSWORD '${POSTGRES_LIZMAP_PASSWORD}';`);
    await adminClient.query(`CREATE DATABASE "${POSTGRES_LIZMAP_DB}";`);
    await adminClient.query(`GRANT ALL PRIVILEGES ON DATABASE "${POSTGRES_LIZMAP_DB}" TO "${POSTGRES_LIZMAP_USER}";`);

    console.log("✅ Role and database created.");

    await adminClient.end();

    // Now connect to Lizmap DB
    const lizmapClient = new Client({
      user: POSTGRES_USER,
      password: POSTGRES_PASSWORD,
      database: POSTGRES_LIZMAP_DB,
      host: process.env.PGHOST || "localhost",
      port: process.env.PGPORT || 5432,
    });

    await lizmapClient.connect();

    console.log("⚙️ Setting up extensions and schema in Lizmap DB...");

    await lizmapClient.query(`CREATE EXTENSION IF NOT EXISTS "postgis";`);
    await lizmapClient.query(`CREATE EXTENSION IF NOT EXISTS "postgis_raster";`);
    await lizmapClient.query(`CREATE SCHEMA "lizmap" AUTHORIZATION "${POSTGRES_LIZMAP_USER}";`);

    console.log("✅ Extensions and schema installed.");

    await lizmapClient.end();
  } catch (err) {
    console.error("❌ Error setting up database:", err.message);
    process.exit(1);
  }
}

main();
