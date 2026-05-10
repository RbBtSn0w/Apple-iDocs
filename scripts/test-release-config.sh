#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROOT_DIR="$ROOT_DIR" node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const root = process.env.ROOT_DIR;

function fail(message) {
  console.error(`[FAIL] ${message}`);
  process.exit(1);
}

function pluginName(plugin) {
  return Array.isArray(plugin) ? plugin[0] : plugin;
}

const releaseConfig = JSON.parse(fs.readFileSync(path.join(root, "npm/.releaserc.json"), "utf8"));
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
if (!workflow.includes("@semantic-release/exec")) {
  fail("release workflow must install @semantic-release/exec");
}
if (workflow.includes("Stage GitHub Release Assets")) {
  fail("release workflow must not stage assets before semantic-release computes nextRelease.version");
}

console.log("[PASS] release configuration preserves versioned asset packaging order.");
NODE
