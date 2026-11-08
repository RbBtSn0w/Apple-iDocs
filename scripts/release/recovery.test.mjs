import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';
import * as release from './release.mjs';

test('trusted main recovery accepts original sealed plan after main advances', () => {
  const directory = mkdtempSync(join(tmpdir(), 'idocs-original-'));
  try {
    const plan = {candidate: 'a'.repeat(40), next: {version: '1.2.3', gitTag: 'v1.2.3'}};
    for (const name of ['plan.json', 'package.tgz', 'idocs-darwin-arm64.tar.gz', 'idocs-darwin-arm64.sha256']) {
      writeFileSync(join(directory, name), name === 'plan.json' ? JSON.stringify(plan) : 'sealed');
    }
    writeFileSync(join(directory, 'artifact.json'), JSON.stringify(release.inspectArtifact(directory, plan, ['plan.json', 'package.tgz', 'idocs-darwin-arm64.tar.gz', 'idocs-darwin-arm64.sha256'])));
    assert.equal(release.recoveryPlan(directory, plan.candidate).next.version, '1.2.3');
    assert.throws(() => release.recoveryPlan(directory, 'b'.repeat(40)), /candidate/);
    writeFileSync(join(directory, 'package.tgz'), 'tampered');
    assert.throws(() => release.recoveryPlan(directory, plan.candidate), /checksum/);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('workflow analyzes without activation and exposes source-bound recovery', () => {
  const workflow = readFileSync('.github/workflows/release.yml', 'utf8');
  assert.doesNotMatch(workflow.split('  verify:')[1].split('    runs-on:')[0], /RELEASE_ENABLED/);
  assert.match(workflow, /recovery-source.mjs/);
  assert.match(workflow, /release-result.json/);
});
