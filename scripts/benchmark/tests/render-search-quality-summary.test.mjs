import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "../../..");
const runner = path.join(repoRoot, "scripts/benchmark/run-random-search-audit.mjs");
const renderer = path.join(repoRoot, "scripts/benchmark/render-search-quality-summary.mjs");
const mockTargets = path.join(repoRoot, "scripts/benchmark/fixtures/mock-target-results.json");

test("summary renderer writes required sections and iDocs failure rows", async () => {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-summary-"));
  try {
    const run = spawnSync(process.execPath, [
      runner,
      "--seed", "1",
      "--sample-size", "6",
      "--mock-targets", mockTargets,
      "--mock-failure",
      "--output-dir", outputDir
    ], { cwd: repoRoot, encoding: "utf8" });
    assert.equal(run.status, 0, run.stderr);

    const summaryPath = path.join(outputDir, "summary.md");
    const render = spawnSync(process.execPath, [
      renderer,
      "--input", path.join(outputDir, "random-search-audit.json"),
      "--output", summaryPath
    ], { cwd: repoRoot, encoding: "utf8" });
    assert.equal(render.status, 0, render.stderr);

    const summary = await readFile(summaryPath, "utf8");
    assert.match(summary, /Run Metadata/);
    assert.match(summary, /Product Summary/);
    assert.match(summary, /Failure Heatmap/);
    assert.match(summary, /iDocs Failures/);
    assert.match(summary, /Competitor Comparison/);
    assert.match(summary, /repro/);
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});
