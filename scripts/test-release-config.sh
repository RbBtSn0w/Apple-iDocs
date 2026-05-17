#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROOT_DIR="$ROOT_DIR" node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const root = process.env.ROOT_DIR;
const expectedNodeEngine = ">=20.8.1";

function fail(message) {
  console.error(`[FAIL] ${message}`);
  process.exit(1);
}

function assertIncludes(haystack, needle, message) {
  if (!haystack.includes(needle)) {
    fail(message);
  }
}

function assertOrder(haystack, first, second, message) {
  const firstIndex = haystack.indexOf(first);
  const secondIndex = haystack.indexOf(second);
  if (firstIndex < 0 || secondIndex < 0 || firstIndex >= secondIndex) {
    fail(message);
  }
}

function pluginName(plugin) {
  return Array.isArray(plugin) ? plugin[0] : plugin;
}

const releaseConfig = JSON.parse(fs.readFileSync(path.join(root, "npm/.releaserc.json"), "utf8"));
const packageJson = JSON.parse(fs.readFileSync(path.join(root, "npm/package.json"), "utf8"));
const packageLock = JSON.parse(fs.readFileSync(path.join(root, "npm/package-lock.json"), "utf8"));
const plugins = releaseConfig.plugins ?? [];
const names = plugins.map(pluginName);

const npmIndex = names.indexOf("@semantic-release/npm");
const execIndex = names.indexOf("@semantic-release/exec");
const gitIndex = names.indexOf("@semantic-release/git");
const githubIndex = names.indexOf("@semantic-release/github");

if (npmIndex < 0) fail("semantic-release npm plugin is missing");
if (execIndex < 0) fail("semantic-release exec plugin is missing");
if (gitIndex < 0) fail("semantic-release git plugin is missing");
if (githubIndex < 0) fail("semantic-release github plugin is missing");
if (!(npmIndex < execIndex && execIndex < gitIndex && execIndex < githubIndex)) {
  fail("release packaging must run after npm prepares package metadata and before git/github publish steps");
}

const execPlugin = plugins[execIndex];
const execConfig = Array.isArray(execPlugin) ? execPlugin[1] : {};
const expectedPrepare = "../scripts/release-package.sh ${nextRelease.version} dist/release/staged";
if (execConfig.prepareCmd !== expectedPrepare) {
  fail(`unexpected semantic-release prepare command: ${execConfig.prepareCmd}`);
}

const workflow = fs.readFileSync(path.join(root, ".github/workflows/ci.yml"), "utf8");
assertIncludes(workflow, "@semantic-release/exec", "release workflow must install @semantic-release/exec");
if (workflow.includes("Stage GitHub Release Assets")) {
  fail("release workflow must not stage assets before semantic-release computes nextRelease.version");
}
assertIncludes(
  workflow,
  "bash ./scripts/test-publish-homebrew-formula.sh",
  "CI must verify the Homebrew formula publish script"
);
assertIncludes(
  workflow,
  "HOMEBREW_TAP_REPOSITORY: RbBtSn0w/homebrew-tap",
  "release workflow must target the configured Homebrew tap repository"
);
assertIncludes(
  workflow,
  "HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}",
  "release workflow must require HOMEBREW_TAP_TOKEN for tap writes"
);
assertIncludes(
  workflow,
  "./scripts/publish-homebrew-formula.sh",
  "release workflow must publish the Homebrew formula"
);
assertOrder(
  workflow,
  "npx semantic-release@25",
  "./scripts/publish-homebrew-formula.sh",
  "Homebrew formula publication must run after semantic-release creates release assets"
);
assertOrder(
  workflow,
  "./scripts/publish-npm-package.sh github",
  "./scripts/publish-homebrew-formula.sh",
  "Homebrew formula publication must run after GitHub Packages publish"
);

if (packageJson.engines?.node !== expectedNodeEngine) {
  fail(`npm package must require Node ${expectedNodeEngine} for @semantic-release/exec`);
}
if (packageLock.packages?.[""]?.engines?.node !== expectedNodeEngine) {
  fail(`npm package lock must require Node ${expectedNodeEngine} for @semantic-release/exec`);
}

console.log("[PASS] release configuration preserves versioned asset packaging order.");
NODE
