#!/usr/bin/env node
const { Client } = require("pg");

async function main() {
  const {
    POSTGRES_LIZMAP_USER,
    POSTGRES_LIZMAP_PASSWORD,
    POSTGRES_LIZMAP_DB
  } = process.env;

  if (!POSTGRES_LIZMAP_USER || !POSTGRES_LIZMAP_PASSWORD || !POSTGRES_LIZMAP_DB) {
    console.error("❌ Missing required environment variables.");
    process.exit(1);
  }

  const client = new Client({
    user: POSTGRES_LIZMAP_USER,
    password: POSTGRES_LIZMAP_PASSWORD,
    database: POSTGRES_LIZMAP_DB,
    host: process.env.PGHOST || "localhost",
    port: process.env.PGPORT || 5432,
  });

  try {
    await client.connect();

    console.log("⚙️ Ensuring Lizmap schema and migration table...");

    await client.query(`
      CREATE SCHEMA IF NOT EXISTS lizmap AUTHORIZATION "${POSTGRES_LIZMAP_USER}";
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS lizmap.schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMP DEFAULT NOW()
      );
    `);

    console.log("✅ Lizmap schema and migration table ready.");
    await client.end();
  } catch (err) {
    console.error("❌ Error setting up schema/migrations:", err.message);
    process.exit(1);
  }
}

main();
