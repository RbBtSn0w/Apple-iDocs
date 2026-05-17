import assert from "node:assert/strict";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
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
    assert.ok(audit.results.every(item => ["resolve", "fetch", "search"].includes(item.capability)));
    const markdown = await readFile(path.join(outputDir, "random-search-audit.md"), "utf8");
    assert.ok(markdown.includes("Capability Summary"));
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

test("runner classifies missing competitor binaries as infrastructure failures", async () => {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-audit-missing-bin-"));
  try {
    const versionsFile = path.join(outputDir, "versions.json");
    await writeFile(versionsFile, `${JSON.stringify({
      installDir: path.join(outputDir, "missing-corrivals"),
      packages: {
        "@kimsungwhee/apple-docs-mcp": { resolvedVersion: "1.0.26" },
        "apple-doc-mcp-server": { resolvedVersion: "1.9.1" },
        "@nshipster/sosumi": { resolvedVersion: "1.0.0" }
      }
    })}\n`);

    const result = spawnSync(process.execPath, [
      runner,
      "--seed", "1",
      "--sample-size", "1",
      "--versions-file", versionsFile,
      "--idocs-binary", "/usr/bin/true",
      "--output-dir", outputDir
    ], { cwd: repoRoot, encoding: "utf8" });

    assert.equal(result.status, 0, result.stderr);
    const audit = JSON.parse(await readFile(path.join(outputDir, "random-search-audit.json"), "utf8"));
    const missingMCP = audit.results.find(item => item.targetId === "apple-docs-mcp");
    assert.equal(missingMCP.classification, "network_error");
    assert.equal(missingMCP.verdict, "infra");
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});

test("runner classifies empty iDocs results with remote timeout diagnostics as infrastructure", async () => {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-audit-idocs-timeout-"));
  try {
    const idocsBinary = path.join(outputDir, "fake-idocs.mjs");
    await writeFile(idocsBinary, `#!/usr/bin/env node
process.stdout.write(JSON.stringify({
  results: [],
  search_diagnostics: [
    { name: "cache", status: "miss", reason: "cache_miss", result_count: 0 },
    { name: "apple", status: "error", reason: "remote_timeout", result_count: 0 },
    { name: "sosumi", status: "error", reason: "remote_timeout", result_count: 0 }
  ]
}));
`);
    await chmod(idocsBinary, 0o755);

    const versionsFile = path.join(outputDir, "versions.json");
    await writeFile(versionsFile, `${JSON.stringify({
      installDir: path.join(outputDir, "missing-corrivals"),
      packages: {
        "@kimsungwhee/apple-docs-mcp": { resolvedVersion: "1.0.26" },
        "apple-doc-mcp-server": { resolvedVersion: "1.9.1" },
        "@nshipster/sosumi": { resolvedVersion: "1.0.0" }
      }
    })}\n`);

    const result = spawnSync(process.execPath, [
      runner,
      "--seed", "1",
      "--sample-size", "1",
      "--versions-file", versionsFile,
      "--idocs-binary", idocsBinary,
      "--output-dir", outputDir
    ], { cwd: repoRoot, encoding: "utf8" });

    assert.equal(result.status, 0, result.stderr);
    const audit = JSON.parse(await readFile(path.join(outputDir, "random-search-audit.json"), "utf8"));
    const idocsResult = audit.results.find(item => item.targetId === "idocs");
    assert.equal(idocsResult.classification, "network_error");
    assert.equal(idocsResult.verdict, "infra");
    assert.equal(audit.issueCollection.action, "none");
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});
