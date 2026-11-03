import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import test from 'node:test';
import { checkEntrypoint, checkPlan, inspectArtifact } from './release.mjs';

test('only main schedule/manual may release', () => {
  for (const event of ['schedule', 'workflow_dispatch']) checkEntrypoint('refs/heads/main', event);
  for (const [ref, event] of [['refs/heads/main', 'push'], ['refs/heads/main', 'pull_request'], ['refs/heads/develop', 'workflow_dispatch']]) {
    assert.throws(() => checkEntrypoint(ref, event));
  }
});

test('publisher rejects stale baseline, candidate, configuration or version', () => {
  const accepted = { candidate: 'a'.repeat(40), baseline: { gitTag: 'v1.0.0', version: '1.0.0', gitHead: 'b'.repeat(40) }, next: { version: '1.0.1', gitTag: 'v1.0.1', channel: null }, configuration: 'digest' };
  checkPlan(accepted, structuredClone(accepted));
  for (const key of ['candidate', 'baseline', 'next', 'configuration']) {
    assert.throws(() => checkPlan(accepted, { ...accepted, [key]: 'changed' }));
  }
});

test('artifact handoff verifies all bytes and source before use', () => {
  const root = mkdtempSync(join(tmpdir(), 'idocs-artifact-test-'));
  try {
    writeFileSync(join(root, 'package.tgz'), 'payload');
    const plan = { candidate: 'a'.repeat(40) };
    const receipt = inspectArtifact(root, plan, ['package.tgz']);
    writeFileSync(join(root, 'artifact.json'), JSON.stringify(receipt));
    inspectArtifact(root, plan);
    assert.throws(() => inspectArtifact(root, { candidate: 'b'.repeat(40) }));
    writeFileSync(join(root, 'package.tgz'), 'tampered');
    assert.throws(() => inspectArtifact(root, plan));
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('real upstream analysis handles release, no-op, breaking footer and invalid history offline', async () => {
  const root = mkdtempSync(join(tmpdir(), 'idocs-analysis-test-'));
  const git = (...args) => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  const analyze = async () => {
    const resultFile = join(root, 'result.json');
    const code = `import {runAnalysis} from ${JSON.stringify(new URL('./release.mjs', import.meta.url).href)}; import {writeFileSync} from 'node:fs'; writeFileSync(${JSON.stringify(resultFile)},JSON.stringify(await runAnalysis(${JSON.stringify(root)})));`;
    await promisify(execFile)(process.execPath, ['--input-type=module', '-e', code]);
    return JSON.parse(readFileSync(resultFile));
  };
  try {
    git('init', '-b', 'main');
    git('config', 'user.name', 'Fixture'); git('config', 'user.email', 'fixture@example.invalid');
    git('commit', '--allow-empty', '-m', 'chore: initial'); git('tag', 'v1.0.0');
    git('commit', '--allow-empty', '-m', 'docs: explain usage');
    assert.equal((await analyze()).next, null);
    git('commit', '--allow-empty', '-m', 'fix: preserve CLI help');
    assert.equal((await analyze()).next.version, '1.0.1');
    git('commit', '--allow-empty', '-m', 'feat!: change CLI contract');
    assert.equal((await analyze()).next.version, '2.0.0');
    git('tag', 'v2.0.0');
    git('commit', '--allow-empty', '-m', 'fix: update flags', '-m', 'BREAKING CHANGE: consumers must update');
    assert.equal((await analyze()).next.version, '3.0.0');
    git('commit', '--allow-empty', '-m', 'Merge an old feature');
    await assert.rejects(analyze(), /Invalid Conventional Commit/);
    git('tag', '-d', 'v1.0.0', 'v2.0.0');
    await assert.rejects(analyze(), /Published baseline is missing/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
