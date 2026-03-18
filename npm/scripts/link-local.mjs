import { chmodSync, copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const npmRoot = resolve(here, "..");
const repoRoot = resolve(npmRoot, "..");
const distDir = resolve(npmRoot, "dist");
const targetPath = resolve(distDir, "idocs");
const frameworksTargetDir = resolve(distDir, "Frameworks");

function info(msg) {
  console.log(`[idocs-cli] ${msg}`);
}

function findFromDerivedData() {
  const command = "find \"$HOME/Library/Developer/Xcode/DerivedData\" -path \"*/Build/Products/Debug/idocs\" -type f 2>/dev/null | head -n 1";
  const result = spawnSync("bash", ["-lc", command], { encoding: "utf8" });
  if (result.status !== 0) return null;
  const value = result.stdout.trim();
  return value.length > 0 ? value : null;
}

function resolveLocalBinary() {
  const envPath = process.env.IDOCS_LOCAL_BINARY;
  if (envPath && existsSync(envPath)) return envPath;

  const candidates = [
    resolve(process.env.HOME ?? "", "Library", "Developer", "Xcode", "DerivedData", "iDocs-codex", "Build", "Products", "Debug", "idocs"),
    resolve(repoRoot, "build", "Debug", "idocs"),
    resolve(repoRoot, ".build", "release", "iDocs"),
    resolve(repoRoot, ".build", "debug", "iDocs")
  ];

  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }

  return findFromDerivedData();
}

const sourcePath = resolveLocalBinary();
if (!sourcePath) {
  console.error("[idocs-cli] Could not locate a local iDocs binary.");
  console.error("[idocs-cli] Build first: ./scripts/tuist-silent.sh build iDocs");
  console.error("[idocs-cli] Or set IDOCS_LOCAL_BINARY=/absolute/path/to/idocs");
  process.exit(1);
}

mkdirSync(distDir, { recursive: true });
copyFileSync(sourcePath, targetPath);
chmodSync(targetPath, 0o755);

const sourceDir = dirname(sourcePath);
rmSync(frameworksTargetDir, { recursive: true, force: true });
mkdirSync(frameworksTargetDir, { recursive: true });

for (const entry of readdirSync(sourceDir)) {
  if (!entry.endsWith(".framework")) continue;
  cpSync(resolve(sourceDir, entry), resolve(frameworksTargetDir, entry), { recursive: true });
}

info(`Linked local binary: ${sourcePath} -> ${targetPath}`);
info(`Copied local frameworks from: ${sourceDir} -> ${frameworksTargetDir}`);
