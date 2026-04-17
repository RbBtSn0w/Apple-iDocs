#!/usr/bin/env node
import { existsSync } from "node:fs";
import { chmodSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const binaryPath = resolve(here, "../dist/idocs");
const frameworksPath = resolve(here, "../dist/Frameworks");

if (!existsSync(binaryPath)) {
  console.error("iDocs binary not found at npm/dist/idocs.");
  console.error("Reinstall @rbbtsn0w/idocs so postinstall can download the matching release asset.");
  console.error("If reinstall still fails, review the npm install output for the underlying packaging error.");
  console.error("For local repository development only, run npm --prefix npm run link-local.");
  process.exit(1);
}

try {
  chmodSync(binaryPath, 0o755);
} catch {
  // Best effort.
}

const frameworkEnv = process.env.DYLD_FRAMEWORK_PATH
  ? `${frameworksPath}:${process.env.DYLD_FRAMEWORK_PATH}`
  : frameworksPath;

const result = spawnSync(binaryPath, process.argv.slice(2), {
  stdio: "inherit",
  env: {
    ...process.env,
    DYLD_FRAMEWORK_PATH: frameworkEnv
  }
});
if (typeof result.status === "number") {
  process.exit(result.status);
}

if (result.error) {
  console.error(`Failed to execute iDocs binary: ${result.error.message}`);
}
process.exit(1);
