import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import test from 'node:test';
import {report} from './train-adapter.mjs';
import {reportExitCode} from '../../.github/release-train/release-result.mjs';

const script = resolve('scripts/release/observe.mjs');
const candidate = 'a'.repeat(40);
function observe(receipts = {}, overrides = {}) {
  const cwd = mkdtempSync(join(tmpdir(), 'idocs-outcome-v2-'));
  try {
    mkdirSync(join(cwd, 'publication-input'));
    mkdirSync(join(cwd, 'result-input'));
    writeFileSync(join(cwd, 'result-input/plan.json'), JSON.stringify({candidate, next: {version: '1.2.3', gitTag: 'v1.2.3'}, baseline: {gitTag: 'v1.2.2'}, notes: 'Original notes'}));
    for (const [name, value] of Object.entries(receipts)) writeFileSync(join(cwd, 'publication-input', name), JSON.stringify(value));
    const needs = {verify: {result: 'success', outputs: {source_sha: candidate, version: '1.2.3', needed: 'true'}}, release: {result: 'success'}, 'publish-homebrew': {result: 'success'}, 'recovery-input': {result: 'skipped'}};
    const result = spawnSync(process.execPath, [script], {cwd, env: {...process.env, GITHUB_STEP_SUMMARY: join(cwd, 'summary.md'), RELEASE_NEEDS: JSON.stringify(needs), RELEASE_TARGETS: '{"github": "release", "npm": "release", "github-packages": "release", "homebrew": "publish-homebrew"}', RELEASE_ENABLED: 'true', GITHUB_SHA: candidate, GITHUB_REPOSITORY: 'example/idocs', ...overrides}, encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    return {result: JSON.parse(readFileSync(join(cwd, 'release-result.json'))), summary: readFileSync(join(cwd, 'summary.md'), 'utf8')};
  } finally {rmSync(cwd, {recursive: true, force: true});}
}
test('successful jobs without channel receipts never complete publication', () => {
  const {result} = observe();
  assert.notEqual(result.publication, 'completed');
  assert.equal(result.targets.github.status, 'unknown');
  assert.equal(result.schema_version, 2);
});
test('legacy or stale receipt cannot promote a channel', () => {
  const {result} = observe({'github-result.json': {status: 'completed'}, 'registries.json': {candidate: 'b'.repeat(40), version: '1.2.3', registries: {npm: 'verified', github: 'verified'}}});
  assert.notEqual(result.targets.github.status, 'completed');
  assert.notEqual(result.targets.npm.status, 'completed');
});
test('disabled publication keeps verification and useful next action visible', () => {
  const {result, summary} = observe({}, {RELEASE_ENABLED: 'false'});
  assert.equal(result.publication, 'disabled');
  assert.match(summary, /Publication disabled/);
  assert.match(summary, /Next|action/i);
});
test('missing original tag or artifact never advertises a recovery command', () => {
  const {result} = observe();
  assert.equal(result.recovery.available, false);
  assert.ok(result.recovery.blocked_reason);
  assert.ok(!result.recovery.command);
});
test('report download failure writes its receipt before failing the native job', () => {
  const cwd=mkdtempSync(join(tmpdir(),'idocs-report-failure-'));
  try {
    const env={...process.env,GITHUB_STEP_SUMMARY:join(cwd,'summary.md'),GITHUB_SHA:candidate,RELEASE_ENABLED:'true',RELEASE_TARGETS:'{"github":"release"}',RELEASE_NEEDS:JSON.stringify({verify:{result:'success',outputs:{source_sha:candidate,version:'1.2.3'}},release:{result:'success'}}),REPORT_DOWNLOADS:'{"analysis":"failure"}'};
    assert.equal(reportExitCode(report({cwd,env})),1);
    const result=JSON.parse(readFileSync(join(cwd,'release-result.json')));
    assert.equal(result.failure_stage,'report-input');
    assert.notEqual(result.publication,'completed');
    assert.match(readFileSync(join(cwd,'summary.md'),'utf8'),/could not be downloaded/);
  } finally {rmSync(cwd,{recursive:true,force:true});}
});

for(const [latest,blocked,confirmed]of [['1.2.3',false,true],['2.0.0',false,true],['1.0.0',false,false],[undefined,false,false],['1.0.0',true,false]])test(`registry outcome binds channel evidence ${latest}/${blocked}`,()=>{
  const integrity='sha512-'+createHash('sha512').update(JSON.stringify('wrapper')).digest('base64');
  const receipt={status:blocked?'unknown':'completed',candidate_sha:candidate,version:'1.2.3',integrity,observed_at:'2026-11-08T00:00:00Z',remote_id:'package@1.2.3',latest_version:latest,channel_observed_at:'2026-11-08T00:00:00Z',...(blocked?{channel_blocked:true,bytes_verified:true,reason:'latest is older'}:{})};
  const recovery={available:true,tag_verified:true,source_run_id:'12',artifact_id:'34',source_attempt:1,digest:'sha256:'+'b'.repeat(64),expires_at:'2099-01-01T00:00:00Z',command:'gh workflow run release.yml -f operation=recover -f source_run_id=12 -f artifact_id=34'};
  const {result}=observe({'package.tgz':'wrapper','registries.json':{candidate,version:'1.2.3',integrity,registries:{npm:blocked?'unknown':'verified'},receipts:{npm:receipt}},'recovery-availability.json':recovery});
  assert.equal(result.targets.npm.status,confirmed?'completed':'unknown');
  if(!confirmed){assert.equal(result.recovery.available,false);assert.equal(result.recovery.source_run_id,'12');assert.equal(result.recovery.command,undefined);assert.match(result.recovery.blocked_reason,/channel|latest/i);}
});
