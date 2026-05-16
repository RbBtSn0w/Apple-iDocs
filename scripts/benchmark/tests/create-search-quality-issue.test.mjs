import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "../../..");
const runner = path.join(repoRoot, "scripts/benchmark/run-random-search-audit.mjs");
const collector = path.join(repoRoot, "scripts/benchmark/create-search-quality-issue.mjs");
const mockTargets = path.join(repoRoot, "scripts/benchmark/fixtures/mock-target-results.json");

async function makeAudit({ mockFailure }) {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-issue-"));
  const args = [
    runner,
    "--seed", "1",
    "--sample-size", "6",
    "--mock-targets", mockTargets,
    "--output-dir", outputDir
  ];
  if (mockFailure) args.push("--mock-failure");
  const run = spawnSync(process.execPath, args, { cwd: repoRoot, encoding: "utf8" });
  assert.equal(run.status, 0, run.stderr);
  return outputDir;
}

test("issue collector no-ops when no actionable iDocs failures exist", async () => {
  const outputDir = await makeAudit({ mockFailure: false });
  try {
    const collect = spawnSync(process.execPath, [
      collector,
      "--input", path.join(outputDir, "random-search-audit.json"),
      "--dry-run"
    ], { cwd: repoRoot, encoding: "utf8" });

    assert.equal(collect.status, 0, collect.stderr);
    assert.equal(JSON.parse(collect.stdout).action, "none");
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});

test("issue collector renders body and comments on existing fingerprint", async () => {
  const outputDir = await makeAudit({ mockFailure: true });
  try {
    const first = spawnSync(process.execPath, [
      collector,
      "--input", path.join(outputDir, "random-search-audit.json"),
      "--dry-run",
      "--print-body"
    ], { cwd: repoRoot, encoding: "utf8" });
    assert.equal(first.status, 0, first.stderr);
    assert.match(first.stdout, /CI run URL/);
    assert.match(first.stdout, /Competitor versions/);
    assert.match(first.stdout, /Fingerprint/);
    assert.match(first.stdout, /automation validation path/);

    const audit = JSON.parse(await readFile(path.join(outputDir, "random-search-audit.json"), "utf8"));
    const mockIssues = path.join(outputDir, "issues.json");
    await import("node:fs/promises").then(fs => fs.writeFile(mockIssues, JSON.stringify([
      { number: 123, body: `Fingerprint: ${audit.issueCollection.fingerprint}` }
    ])));

    const second = spawnSync(process.execPath, [
      collector,
      "--input", path.join(outputDir, "random-search-audit.json"),
      "--dry-run",
      "--mock-existing-issues", mockIssues
    ], { cwd: repoRoot, encoding: "utf8" });
    assert.equal(second.status, 0, second.stderr);
    assert.equal(JSON.parse(second.stdout).action, "commented");
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});
