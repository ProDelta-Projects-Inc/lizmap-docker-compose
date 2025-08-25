#!/usr/bin/env node
const { execSync } = require("child_process");
const path = require("path");
const os = require("os");

// Script directory
const scriptDir = __dirname;
const installSource = scriptDir;
const installDest = path.join(scriptDir, "lizmap");

// Read version from env or fallback
const lizmapVersionTag = process.env.LIZMAP_VERSION_TAG || "3.9";
const qgisVersionTag = process.env.QGIS_VERSION_TAG || "ltr-rc";

// Convert Windows paths to Docker-style
function toDockerPath(p) {
  if (os.platform() === "win32") {
    return p.replace(/\\/g, "/").replace(/^([A-Za-z]):/, (_, d) => `/${d.toLowerCase()}`);
  }
  return p;
}

// Command to run configuration inside container
const dockerCmd = [
  "docker run -it --rm",
  `-u 1000:1000`,
  `-e INSTALL_SOURCE=/install`,
  `-e INSTALL_DEST=/lizmap`,
  `-e "LIZMAP_DIR=${toDockerPath(installDest)}"`,
  `-e QGSRV_SERVER_PLUGINPATH=/lizmap/plugins`,
  `-e LIZMAP_VERSION_TAG=${lizmapVersionTag}`,
  `-e QGIS_VERSION_TAG=${qgisVersionTag}`,
  `-v "${toDockerPath(installSource)}:/install"`,
  `-v "${toDockerPath(installDest)}:/lizmap"`,
  `-v "${toDockerPath(scriptDir)}:/src"`,
  `--entrypoint /src/configure.sh`,
  `3liz/qgis-map-server:${qgisVersionTag} configure`
].join(" ");

try {
  console.log("Running configure inside container:");
  console.log(dockerCmd);
  execSync(dockerCmd, { stdio: "inherit", shell: true });

  console.log("\n Configuration complete.");
  console.log("Next steps:");
  console.log("  docker compose pull");
  console.log("  docker compose up");
} catch (err) {
  console.error("Error during configuration:", err.message);
  process.exit(1);
}
