import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';
import * as release from './release.mjs';

test('generated notes must match the exact original plan before publication', () => {
  const expected = {candidate:'a'.repeat(40),notes:'Original notes'};
  assert.doesNotThrow(()=>release.checkPlan(expected,{...expected}));
  assert.throws(()=>release.checkPlan(expected,{...expected,notes:'Changed notes'}),/notes/);
});

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

test('Homebrew follows a successful publisher across skipped alternate branches', () => {
  const workflow = readFileSync('.github/workflows/release.yml', 'utf8');
  const homebrew = workflow.split('  publish-homebrew:')[1].split('  result:')[0];
  assert.match(homebrew, /if:.*!cancelled\(\)/);
  assert.match(homebrew, /if:.*needs\.release\.result == 'success'/);
  assert.match(homebrew, /if:.*needs\.release\.outputs\.released == 'true'/);
});

test('every release job installs npm without mutating the runner toolchain', () => {
  const workflow = readFileSync('.github/workflows/release.yml', 'utf8');
  const commands = workflow.split('\n').filter(line => /^\s+npm install\b/.test(line) && /\bnpm@/.test(line));
  assert.equal(commands.length, 3, 'analysis, recovery validation and publication each bootstrap npm');
  for (const command of commands) {
    assert.doesNotMatch(command, /(?:--global|\s-g)(?:\s|$)/);
    assert.match(command, /--prefix "\$RUNNER_TEMP\/release-npm".*npm@12\.2\.2/);
  }
  const steps = workflow.split(/\n      - /);
  for (const step of steps.filter(step => step.includes('npm install ') && /\bnpm@/.test(step))) {
    assert.match(step, /echo "\$RUNNER_TEMP\/release-npm\/node_modules\/\.bin" >> "\$GITHUB_PATH"/);
    assert.doesNotMatch(step, /\bnpm ci\b/, 'GITHUB_PATH takes effect in the following step');
  }
});
