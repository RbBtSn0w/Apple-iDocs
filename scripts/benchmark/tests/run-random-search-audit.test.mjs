import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "../../..");
const runner = path.join(repoRoot, "scripts/benchmark/run-random-search-audit.mjs");
const mockTargets = path.join(repoRoot, "scripts/benchmark/fixtures/mock-target-results.json");

test("mock audit completes with artifacts and does not fail for quality findings", async () => {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-audit-"));
  try {
    const result = spawnSync(process.execPath, [
      runner,
      "--seed", "1",
      "--sample-size", "6",
      "--mock-targets", mockTargets,
      "--mock-failure",
      "--output-dir", outputDir
    ], { cwd: repoRoot, encoding: "utf8" });

    assert.equal(result.status, 0, result.stderr);
    const audit = JSON.parse(await readFile(path.join(outputDir, "random-search-audit.json"), "utf8"));
    assert.equal(audit.seed, 1);
    assert.equal(audit.sampleSize, 6);
    assert.equal(audit.remoteOnly, true);
    assert.equal(audit.simulatedFailure, true);
    assert.equal(audit.localDocsDiagnostic.reason, "local_docs_unavailable");
    assert.ok(audit.results.some(item => item.targetId === "idocs" && item.verdict === "fail"));
    assert.ok(audit.results.every(item => item.classification && item.verdict));
    const markdown = await readFile(path.join(outputDir, "random-search-audit.md"), "utf8");
    assert.ok(markdown.includes("Competitor Comparison"));
    assert.ok(markdown.includes("automation validation path"));
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});

test("mock audit records deterministic same-seed sample and target versions", async () => {
  const firstDir = await mkdtemp(path.join(os.tmpdir(), "idocs-audit-a-"));
  const secondDir = await mkdtemp(path.join(os.tmpdir(), "idocs-audit-b-"));
  try {
    for (const outputDir of [firstDir, secondDir]) {
      const result = spawnSync(process.execPath, [
        runner,
        "--seed", "42",
        "--sample-size", "6",
        "--mock-targets", mockTargets,
        "--output-dir", outputDir
      ], { cwd: repoRoot, encoding: "utf8" });
      assert.equal(result.status, 0, result.stderr);
    }

    const first = JSON.parse(await readFile(path.join(firstDir, "random-search-audit.json"), "utf8"));
    const second = JSON.parse(await readFile(path.join(secondDir, "random-search-audit.json"), "utf8"));
    assert.deepEqual(first.sample, second.sample);
    assert.equal(first.targets.find(target => target.id === "apple-docs-mcp").resolvedVersion, "1.0.26");
    assert.ok(first.results.some(result => result.rawEvidence));
  } finally {
    await rm(firstDir, { recursive: true, force: true });
    await rm(secondDir, { recursive: true, force: true });
  }
});

test("runner reports infrastructure failure when requested", async () => {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-audit-infra-"));
  try {
    const result = spawnSync(process.execPath, [
      runner,
      "--seed", "1",
      "--sample-size", "1",
      "--mock-infra-failure",
      "--output-dir", outputDir
    ], { cwd: repoRoot, encoding: "utf8" });

    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /mock infrastructure failure/i);
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});
