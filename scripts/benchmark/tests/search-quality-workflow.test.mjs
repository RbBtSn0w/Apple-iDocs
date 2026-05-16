import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "../../..");
const workflowPath = path.join(repoRoot, ".github/workflows/search-quality-race.yml");

test("workflow has required triggers, permissions, stages, and remote-only environment", async () => {
  const workflow = await readFile(workflowPath, "utf8");

  assert.match(workflow, /name:\s*Search Quality Race/);
  assert.match(workflow, /schedule:/);
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /seed:/);
  assert.match(workflow, /sample_size:/);
  assert.match(workflow, /package_spec:/);
  assert.match(workflow, /mock_failure:/);
  assert.match(workflow, /runs-on:\s*macos-15/);
  assert.match(workflow, /contents:\s*read/);
  assert.match(workflow, /issues:\s*write/);
  assert.match(workflow, /Setup Tuist/);
  assert.match(workflow, /Setup Node/);
  assert.match(workflow, /Build iDocs CLI/);
  assert.match(workflow, /install-corrival-releases\.mjs/);
  assert.match(workflow, /run-random-search-audit\.mjs/);
  assert.match(workflow, /GITHUB_STEP_SUMMARY/);
  assert.match(workflow, /actions\/upload-artifact/);
  assert.match(workflow, /create-search-quality-issue\.mjs/);
  assert.match(workflow, /IDOCS_XCODE_DOC_CACHE_PATH/);
});
