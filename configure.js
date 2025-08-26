#!/usr/bin/env node
const fs = require("fs")
const path = require("path")
const os = require("os")
const { execSync } = require("child_process")

// ---------- Configuration ----------

const scriptDir = __dirname
const installDest = path.join(scriptDir, "lizmap")
const installSource = scriptDir

// Fixed versions
const LIZMAP_VERSION_TAG = "3.9"
const QGIS_VERSION_TAG = "ltr-rc"

// Postgres defaults
const POSTGIS_VERSION = process.env.POSTGIS_VERSION || "17-3"
const POSTGRES_PASSWORD = process.env.POSTGRES_PASSWORD || "postgres"
const POSTGRES_LIZMAP_DB = process.env.POSTGRES_LIZMAP_DB || "lizmap"
const POSTGRES_LIZMAP_USER = process.env.POSTGRES_LIZMAP_USER || "lizmap"
const POSTGRES_LIZMAP_PASSWORD = process.env.POSTGRES_LIZMAP_PASSWORD || "lizmap1234!"
const POSTGIS_ALIAS = process.env.POSTGIS_ALIAS || "db.lizmap"

// Worker and port defaults
const QGIS_MAP_WORKERS = process.env.QGIS_MAP_WORKERS || 4
const WPS_NUM_WORKERS = process.env.WPS_NUM_WORKERS || 1
const LIZMAP_PORT = process.env.LIZMAP_PORT || "127.0.0.1:8090"
const OWS_PORT = process.env.OWS_PORT || "127.0.0.1:8091"
const WPS_PORT = process.env.WPS_PORT || "127.0.0.1:8092"
const POSTGIS_PORT = process.env.POSTGIS_PORT || "127.0.0.1:5432"

const COPY_COMPOSE_FILE = true // copy docker-compose.yml

// ---------- Helpers ----------

function mkdirSafe(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true })
}

function writeFileSafe(file, content, mode) {
  mkdirSafe(path.dirname(file))
  fs.writeFileSync(file, content, { mode: mode || 0o644 })
}

function toDockerPath(p) {
  if (os.platform() === "win32") {
    return p.replace(/\\/g, "/").replace(/^([A-Za-z]):/, (_, d) => `/${d.toLowerCase()}`)
  }
  return p
}

// ---------- Step 1: Create .env ----------

const envContent = `
LIZMAP_PROJECTS=${path.join(installDest, "instances")}
LIZMAP_DIR=${installDest}
LIZMAP_UID=${process.getuid ? process.getuid() : 1000}
LIZMAP_GID=${process.getgid ? process.getgid() : 1000}
LIZMAP_VERSION_TAG=${LIZMAP_VERSION_TAG}
QGIS_VERSION_TAG=${QGIS_VERSION_TAG}
POSTGIS_VERSION=${POSTGIS_VERSION}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_LIZMAP_DB=${POSTGRES_LIZMAP_DB}
POSTGRES_LIZMAP_USER=${POSTGRES_LIZMAP_USER}
POSTGRES_LIZMAP_PASSWORD=${POSTGRES_LIZMAP_PASSWORD}
QGIS_MAP_WORKERS=${QGIS_MAP_WORKERS}
WPS_NUM_WORKERS=${WPS_NUM_WORKERS}
LIZMAP_PORT=${LIZMAP_PORT}
OWS_PORT=${OWS_PORT}
WPS_PORT=${WPS_PORT}
POSTGIS_PORT=${POSTGIS_PORT}
POSTGIS_ALIAS=${POSTGIS_ALIAS}
`.trim()

writeFileSafe(path.join(installDest, ".env"), envContent)

// ---------- Step 2: Copy lizmap.dir files ----------

const srcDir = path.join(installSource, "lizmap.dir")
if (fs.existsSync(srcDir)) {
  fs.cpSync(srcDir, installDest, { recursive: true })
}

// ---------- Step 3: Create directories ----------

const dirs = [
  "plugins",
  "processing",
  "wps-data",
  "www",
  "var/log/nginx",
  "var/nginx-cache",
  "var/lizmap-theme-config",
  "var/lizmap-db",
  "var/lizmap-config",
  "var/lizmap-log",
  "var/lizmap-modules",
  "var/lizmap-my-packages"
]

dirs.forEach(d => mkdirSafe(path.join(installDest, d)))

// ---------- Step 4: Create pg_service.conf ----------

const pgServiceConf = `
[lizmap_local]
host=${POSTGIS_ALIAS}
port=5432
dbname=${POSTGRES_LIZMAP_DB}
user=${POSTGRES_LIZMAP_USER}
password=${POSTGRES_LIZMAP_PASSWORD}

[postgis1]
host=${POSTGIS_ALIAS}
port=5432
dbname=${POSTGRES_LIZMAP_DB}
user=${POSTGRES_LIZMAP_USER}
password=${POSTGRES_LIZMAP_PASSWORD}
`.trim()

writeFileSafe(path.join(installDest, "etc/pg_service.conf"), pgServiceConf, 0o600)

// ---------- Step 5: Create lizmap profile ----------

const profileDir = path.join(installDest, "etc/profiles.d")
mkdirSafe(profileDir)

const lizmapProfile = `
[jdb:jauth]
driver=pgsql
host=${POSTGIS_ALIAS}
port=5432
database=${POSTGRES_LIZMAP_DB}
user=${POSTGRES_LIZMAP_USER}
password="${POSTGRES_LIZMAP_PASSWORD}"
search_path=lizmap,public
`.trim()

writeFileSafe(path.join(profileDir, "lizmap_local.ini.php"), lizmapProfile, 0o600)

// ---------- Step 6: Install plugins inside Docker container ----------

const pluginsDir = path.join(installDest, "plugins");
mkdirSafe(pluginsDir);

try {
  console.log("\nInstalling Lizmap plugins into:", pluginsDir);

  const repos = {
    "lizmap_server": "https://github.com/3liz/qgis-lizmap-server-plugin.git",
    "atlasprint": "https://github.com/3liz/qgis-atlasprint.git",
    "wfsOutputExtension": "https://github.com/3liz/qgis-wfsOutputExtension.git"
  };

  for (const [name, repo] of Object.entries(repos)) {
    const target = path.join(pluginsDir, name);
    if (!fs.existsSync(target)) {
      execSync(`git clone --depth 1 ${repo} ${target}`, { stdio: "inherit" });
    } else {
      console.log(`✔ Plugin ${name} already present`);
    }
  }

  console.log("✅ Plugins installed locally.");
} catch (err) {
  console.error("❌ Error installing Lizmap plugins:", err.message);
  process.exit(1);
}

// ---------- Step 7: Copy docker-compose.yml ----------

const composeSrc = path.join(installSource, "docker-compose.yml")
const composeDest = path.join(installDest, "docker-compose.yml")
if (COPY_COMPOSE_FILE && fs.existsSync(composeSrc)) {
  fs.copyFileSync(composeSrc, composeDest)
}

// ---------- Done ----------

console.log("\n✅ Lizmap configuration complete in:", installDest)
console.log("Next steps:")
console.log("  docker compose pull")
console.log("  docker compose up")
