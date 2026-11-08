import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {createHash} from 'node:crypto';
import test from 'node:test';
const script = resolve('scripts/release/observe.mjs');
function observe(needs, receipt) {
  const cwd = mkdtempSync(join(tmpdir(), 'release-observation-'));
  try {
    if (receipt) { mkdirSync(join(cwd, 'publication-input')); for(const [name, value] of Object.entries(receipt)) writeFileSync(join(cwd, 'publication-input', name), name.endsWith('.json') ? JSON.stringify(value) : value); }
    execFileSync(process.execPath, [script], {cwd, env: {...process.env, GITHUB_STEP_SUMMARY: join(cwd, 'summary.md'), RELEASE_NEEDS: JSON.stringify(needs), RELEASE_TARGETS: '{"github": "release", "npm": "release", "github-packages": "release"}', RELEASE_ENABLED: 'true', RELEASE_OPERATION: 'release', GITHUB_SHA: 'a'.repeat(40)}, stdio: 'pipe'});
    const result = JSON.parse(readFileSync(join(cwd, 'release-result.json')));
    assert.match(readFileSync(join(cwd, 'summary.md'), 'utf8'), /verification:/i);
    return result;
  } finally {rmSync(cwd, {recursive: true, force: true});}
}
test('always result reports failed verification even when all publishers are skipped', () => {
  const result = observe({verify: {result: 'failure'}, 'recovery-input': {result: 'skipped'}, 'publish': {result: 'skipped'}, 'publish-pypi': {result: 'skipped'}, release: {result:'skipped'}});
  assert.equal(result.verification, 'failed');
  assert.equal(result.publication, 'failed');
});
test('later registry failure preserves verified independent target results', () => {
  const identity = {status: 'completed', candidate_sha: 'a'.repeat(40), version: '1.2.3', observed_at: '2026-11-08T00:00:00Z', remote_id: '42', url: 'https://example.invalid/verified'};
  const integrity = 'sha512-' + createHash('sha512').update('original package').digest('base64');
  const result = observe({verify: {result: 'success', outputs: {source_sha: 'a'.repeat(40), version: '1.2.3'}}, release: {result: 'failure'}}, {
    'github-observation.json': {targets: {github: identity}}, 'package.tgz': 'original package',
    'registries.json': {candidate: identity.candidate_sha, version: identity.version, integrity, registries: {npm: 'verified', github: 'unknown'}, receipts: {npm: {...identity, integrity, latest_version: identity.version, channel_observed_at: identity.observed_at}}},
  });
  assert.equal(result.targets.github.status, 'completed');
  assert.equal(result.targets.npm.status, 'completed');
  assert.equal(result.targets['github-packages'].status, 'unknown');
  assert.equal(result.publication, 'partial');
});
