import { chmodSync, cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const npmRoot = resolve(here, "..");
const distDir = resolve(npmRoot, "dist");
const binaryPath = resolve(distDir, "idocs");
const frameworksPath = resolve(distDir, "Frameworks");
const tmpArchive = resolve(distDir, "idocs-darwin-arm64.tar.gz");
const force = process.argv.includes("--force");
const strictInstall = process.env.IDOCS_NPM_STRICT_INSTALL === "1";

function log(msg) {
  console.log(`[idocs-cli] ${msg}`);
}

function fail(msg, err) {
  console.error(`[idocs-cli] ${msg}`);
  if (err?.message) {
    console.error(`[idocs-cli] ${err.message}`);
  }
  if (strictInstall) {
    process.exit(1);
  }
}

function getVersion() {
  const pkg = JSON.parse(readFileSync(resolve(npmRoot, "package.json"), "utf8"));
  return pkg.version;
}

function releaseBaseURL(version) {
  const configured = process.env.IDOCS_RELEASE_BASE_URL;
  if (configured && configured.trim().length > 0) {
    return configured.replaceAll("{version}", version);
  }
  return `https://github.com/OWNER/REPO/releases/download/v${version}`;
}

function normalizeExtractedLayout(root) {
  const bundleDir = resolve(root, "idocs-darwin-arm64");
  if (!existsSync(bundleDir)) {
    return;
  }

  if (existsSync(resolve(bundleDir, "idocs"))) {
    cpSync(resolve(bundleDir, "idocs"), binaryPath);
  }

  const frameworksDir = resolve(bundleDir, "Frameworks");
  if (existsSync(frameworksDir)) {
    rmSync(frameworksPath, { recursive: true, force: true });
    cpSync(frameworksDir, frameworksPath, { recursive: true });
  }

  rmSync(bundleDir, { recursive: true, force: true });
}

async function main() {
  mkdirSync(distDir, { recursive: true });

  if (!force && existsSync(binaryPath)) {
    chmodSync(binaryPath, 0o755);
    log("Binary already present; skipping download.");
    return;
  }

  const version = getVersion();
  const assetName = "idocs-darwin-arm64.tar.gz";
  const url = `${releaseBaseURL(version)}/${assetName}`;

  log(`Downloading ${assetName} from ${url}`);
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status} when downloading ${url}`);
    }

    const data = Buffer.from(await response.arrayBuffer());
    writeFileSync(tmpArchive, data);

    const extract = spawnSync("tar", ["-xzf", tmpArchive, "-C", distDir], { stdio: "pipe" });
    if (extract.status !== 0) {
      throw new Error(`tar extraction failed: ${extract.stderr.toString("utf8").trim()}`);
    }

    normalizeExtractedLayout(distDir);

    if (!existsSync(binaryPath)) {
      throw new Error("archive extracted but npm/dist/idocs not found");
    }

    if (!existsSync(frameworksPath)) {
      const entries = readdirSync(distDir).filter((item) => item.endsWith(".framework"));
      if (entries.length > 0) {
        mkdirSync(frameworksPath, { recursive: true });
        for (const entry of entries) {
          cpSync(resolve(distDir, entry), resolve(frameworksPath, entry), { recursive: true });
          rmSync(resolve(distDir, entry), { recursive: true, force: true });
        }
      }
    }

    chmodSync(binaryPath, 0o755);
    unlinkSync(tmpArchive);
    log("Binary installed successfully.");
  } catch (error) {
    fail("Binary download failed. Install will continue in non-strict mode.", error);
  }
}

main();
