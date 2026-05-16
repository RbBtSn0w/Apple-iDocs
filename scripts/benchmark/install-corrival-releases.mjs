#!/usr/bin/env node
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { DEFAULT_PACKAGE_SPECS, parsePackageSpecs } from "./search-quality-lib.mjs";

const args = parseArgs(process.argv.slice(2));
const dryRun = args.has("dry-run");
const packageSpec = args.get("package-spec") ?? DEFAULT_PACKAGE_SPECS.join(",");
const output = args.get("output") ?? "search-quality-corrival-versions.json";
const installDir = args.get("install-dir") ?? ".tmp/search-quality-corrivals";

const packages = parsePackageSpecs(packageSpec);
const metadata = {
  generatedAt: new Date().toISOString(),
  installDir,
  dryRun,
  packages: {}
};

await mkdir(path.dirname(output), { recursive: true });

if (!dryRun) {
  await mkdir(installDir, { recursive: true });
}

for (const item of packages) {
  const resolvedVersion = dryRun
    ? resolveDryRunVersion(item)
    : resolveNPMVersion(item);

  metadata.packages[item.packageName] = {
    requestedSpec: item.requestedSpec,
    resolvedVersion,
    raw: item.raw
  };
}

if (!dryRun) {
  const install = spawnSync(
    "npm",
    [
      "install",
      "--prefix",
      installDir,
      "--no-save",
      "--no-audit",
      "--no-fund",
      ...packages.map(item => `${item.packageName}@${item.requestedSpec}`)
    ],
    { encoding: "utf8" }
  );
  if (install.status !== 0) {
    process.stderr.write(install.stderr || install.stdout);
    process.exit(2);
  }
}

await writeFile(output, `${JSON.stringify(metadata, null, 2)}\n`);
process.stdout.write(`${JSON.stringify(metadata)}\n`);

function resolveDryRunVersion(item) {
  return item.requestedSpec === "latest" ? "dry-run-latest" : item.requestedSpec;
}

function resolveNPMVersion(item) {
  const view = spawnSync(
    "npm",
    ["view", `${item.packageName}@${item.requestedSpec}`, "version", "--json"],
    { encoding: "utf8" }
  );
  if (view.status !== 0) {
    process.stderr.write(view.stderr || view.stdout);
    process.exit(2);
  }
  return String(JSON.parse(view.stdout)).replace(/^"|"$/g, "");
}

function parseArgs(argv) {
  const parsed = new Map();
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      parsed.set(key, true);
    } else {
      parsed.set(key, next);
      index += 1;
    }
  }
  return parsed;
}
