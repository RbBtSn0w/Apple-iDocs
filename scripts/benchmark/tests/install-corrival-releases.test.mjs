import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "../../..");
const installer = path.join(repoRoot, "scripts/benchmark/install-corrival-releases.mjs");

test("dry-run installer records exact package metadata without network mutation", async () => {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-install-"));
  try {
    const output = path.join(outputDir, "versions.json");
    const result = spawnSync(process.execPath, [
      installer,
      "--dry-run",
      "--package-spec", "@kimsungwhee/apple-docs-mcp@1.0.26,apple-doc-mcp-server@1.9.1,@nshipster/sosumi@1.0.0",
      "--output", output
    ], { cwd: repoRoot, encoding: "utf8" });

    assert.equal(result.status, 0, result.stderr);
    const versions = JSON.parse(await readFile(output, "utf8"));
    assert.deepEqual(Object.keys(versions.packages), [
      "@kimsungwhee/apple-docs-mcp",
      "apple-doc-mcp-server",
      "@nshipster/sosumi"
    ]);
    assert.equal(versions.packages["@kimsungwhee/apple-docs-mcp"].resolvedVersion, "1.0.26");
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});
