import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import YAML from 'yaml';
import { makePreview, tarballName, verifyArtifact } from '../../.github/pr-preview/artifact.mjs';
import { artifactName, marker, renderCard, selectArtifact, updateCard } from '../../.github/pr-preview/github.mjs';
import { publishPreview } from '../../.github/pr-preview/publish.mjs';
import { previewVersion, requireNewerPreview } from '../../.github/pr-preview/version.mjs';
import { createNpmObservationBudget } from '../../.github/release-train/npm-view.mjs';

const owner = 'RbBtSn0w';
const repo = 'Apple-iDocs';
const repository = `${owner}/${repo}`;
const head = '0123456789'.repeat(4);
const receipt = { pr: '42', head, run: '123', attempt: '1', version: `1.11.1-dev.pr42.g${head}.r123.a1`, baseline: '1.11.0', sha256: 'a'.repeat(64) };
const prInfo = { state: 'open', base: { ref: 'main', repo: { full_name: repository } }, head: { sha: head, repo: { full_name: repository } } };

test('versions follow the current stable registry and accept all-numeric commits', () => {
  assert.equal(previewVersion('1.10.0', '1.11.0', receipt), receipt.version);
  assert.equal(previewVersion('2.0.0', '1.11.0', receipt), `2.0.0-dev.pr42.g${head}.r123.a1`);
  assert.equal(previewVersion('1.10.0', null, receipt), `1.10.1-dev.pr42.g${head}.r123.a1`);
  assert.equal(previewVersion('1.10.0', '1.11.0', { ...receipt, attempt: '2' }), `1.11.1-dev.pr42.g${head}.r123.a2`);
  assert.equal(previewVersion('1.10.0', '1.11.0', { ...receipt, run: '124' }), `1.11.1-dev.pr42.g${head}.r124.a1`);
  assert.throws(() => previewVersion('1.10.0', '1.11.9-dev', receipt), /stable SemVer/);
  assert.throws(() => previewVersion('1.10.0', '1.11.9', { ...receipt, head: 'deadbee' }), /full head SHA/);
  assert.throws(() => requireNewerPreview(receipt.version, '1.11.1'), /must be newer/);
});

test('package the native archive once and reject invalid receipts, wrapper metadata and archive bytes', () => {
  const root = mkdtempSync(join(tmpdir(), 'idocs-preview-test-'));
  try {
    const source = join(root, 'source');
    mkdirSync(join(source, 'scripts'), { recursive: true });
    cpSync(resolve('npm/bin'), join(source, 'npm/bin'), { recursive: true });
    cpSync(resolve('npm/README.md'), join(source, 'npm/README.md'));
    const manifest = JSON.parse(readFileSync('npm/package.json'));
    writeFileSync(join(source, 'npm/package.json'), JSON.stringify({ ...manifest, version: '1.10.0' }));
    execFileSync('git', ['init', '-q', source]);
    execFileSync('git', ['-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgSign=false',
      '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'test fixture', '--allow-empty'], { cwd: source });
    const sha = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: source, encoding: 'utf8' }).trim();
    const env = { ...process.env, PR_NUMBER: '42', PR_HEAD: sha, SOURCE_RUN_ID: '123', SOURCE_ATTEMPT: '2' };
    writeFileSync(join(source, 'scripts/release-package.sh'), `set -eu
      test ! -f called
      touch called
      bundle="$2/idocs-darwin-arm64"
      mkdir -p "$bundle"
      cp /bin/echo "$bundle/idocs"
      printf '%s\\n' "$1" > "$bundle/idocs.version"
      tar -czf "$2/idocs-darwin-arm64.tar.gz" -C "$2" idocs-darwin-arm64
    `);
    const directory = join(root, 'artifact');
    let smokes = 0;
    const made = makePreview({ source, directory, env, lookupLatest: () => { throw new Error('synthetic lookup outage'); },
      smoke: (archive, version) => {
        smokes++;
        assert.equal(archive, join(directory, tarballName));
        assert.equal(version, `1.10.1-dev.pr42.g${sha}.r123.a2`);
      } });
    assert.equal(smokes, 1);
    assert.equal(made.baseline, null);
    assert.deepEqual(verifyArtifact(directory, env), made);
    assert.throws(() => verifyArtifact(directory, { ...env, PR_HEAD: head }), /Wrong preview head/);
    assert.throws(() => verifyArtifact(directory, { ...env, SOURCE_ATTEMPT: '3' }), /Wrong preview attempt/);
    for (const [field, value, error] of [['name', 'wrong', /package name/], ['version', '1.0.0', /version identity/],
      ['version', made.version.replace('-dev', '-other-dev'), /version identity/],
      ['version', made.version.replace('.a2', '.a3'), /version identity/],
      ['nativeSha256', 'wrong', /native archive checksum/], ['integrity', 'wrong', /package integrity/]]) {
      writeFileSync(join(directory, 'receipt.json'), JSON.stringify({ ...made, [field]: value }));
      assert.throws(() => verifyArtifact(directory, env), error);
    }
    const archive = join(directory, tarballName);
    const bytes = readFileSync(archive);
    const unpack = join(root, 'unpacked');
    mkdirSync(unpack);
    execFileSync('tar', ['-xzf', archive, '-C', unpack]);
    const manifestPath = join(unpack, 'package/package.json');
    const original = JSON.parse(readFileSync(manifestPath));
    for (const [field, value, error] of [['name', '@rbbtsn0w/wrong', /Wrong tarball package name/], ['version', '1.2.3', /Wrong tarball version/]]) {
      writeFileSync(manifestPath, JSON.stringify({ ...original, [field]: value }));
      execFileSync('tar', ['-czf', archive, '-C', unpack, 'package']);
      const repacked = readFileSync(archive);
      const sha256 = createHash('sha256').update(repacked).digest('hex');
      const integrity = 'sha512-' + createHash('sha512').update(repacked).digest('base64');
      writeFileSync(join(directory, 'receipt.json'), JSON.stringify({ ...made, sha256, integrity }));
      writeFileSync(join(directory, 'SHA256SUMS'), `${sha256}  ${tarballName}\n`);
      assert.throws(() => verifyArtifact(directory, env), error);
    }
    writeFileSync(join(directory, 'receipt.json'), JSON.stringify(made));
    writeFileSync(archive, Buffer.concat([bytes, Buffer.from('extra')]));
    assert.throws(() => verifyArtifact(directory, env), /package checksum/);
  } finally { rmSync(root, { force: true, recursive: true }); }
});

test('select the successful upload attempt rather than the latest comment-only attempt', async () => {
  const run = { id: 123, path: '.github/workflows/ci.yml', event: 'pull_request', conclusion: 'success', run_attempt: 3, head_sha: head,
    repository: { full_name: repository }, head_repository: { full_name: repository }, pull_requests: [{ number: 42, head: { sha: head } }] };
  const packer = attempt => ({ run_id: run.id, run_attempt: attempt, name: 'iDocs PR preview package', conclusion: 'success',
    steps: [{ name: 'Upload verified preview', conclusion: 'success' }] });
  const artifact = (attempt, id, expired = false) => ({ id, expired, name: artifactName({ ...receipt, attempt }) });
  const github = (artifacts, pr = prInfo) => ({
    rest: {
      actions: { getWorkflowRun: async () => ({ data: run }), listJobsForWorkflowRun() {}, listWorkflowRunArtifacts() {} },
      pulls: { get: async () => ({ data: pr }) },
    },
    async paginate(method, options) {
      if (method === this.rest.actions.listJobsForWorkflowRun) {
        assert.equal(options.filter, 'all');
        return [packer(1), packer(2), { ...packer(3), steps: [{ name: 'Upload verified preview', conclusion: 'skipped' }] }];
      }
      return artifacts;
    },
  });
  const select = (artifacts, pr) => selectArtifact(github(artifacts, pr), { owner, repo, sourceRun: '123' });
  assert.deepEqual(await select([artifact(1, 8), artifact(2, 9, true), artifact(3, 10)]),
    { ...Object.fromEntries(['pr', 'head', 'run', 'attempt'].map(key => [key, receipt[key]])), artifact: '8' });
  assert.equal((await select([artifact(1, 8), artifact(2, 9)])).artifact, '9');
  await assert.rejects(select([artifact(1, 8, true)]), /missing or expired/);
  await assert.rejects(select([artifact(2, 9), artifact(2, 10)]), /Ambiguous/);
  await assert.rejects(select([artifact(1, 8)], { ...prInfo, head: { ...prInfo.head, sha: 'b'.repeat(40) } }), /current PR head/);
  await assert.rejects(select([artifact(1, 8)], { ...prInfo, head: { ...prInfo.head, repo: { full_name: 'fork/Apple-iDocs' } } }), /current PR head/);
});

test('the card validates head, preserves registry evidence and avoids duplicate writes', async () => {
  const card = renderCard({ receipt, repository, artifact: '456', registry: { npmjs: { available: true, next: false }, 'github-packages': { available: false } } });
  assert.ok(card.indexOf(`@rbbtsn0w/idocs@${receipt.version}`) < card.indexOf('@rbbtsn0w/idocs@next'));
  assert.match(card, /did not confirm `next`/);
  assert.doesNotMatch(card, /#### GitHub Packages/);
  assert.match(card, /gh run download 123.*idocs-pr-42-012345.*attempt-1/);
  assert.match(card, /shasum -a 256 -c SHA256SUMS/);
  const comments = [{ id: 1, user: { login: 'contributor' }, body: marker }];
  let current = prInfo;
  const writes = [];
  const github = { paginate: async () => comments, rest: { pulls: { get: async () => ({ data: current }) }, issues: {
    createComment: async ({ body }) => { comments.push({ id: 2, user: { login: 'github-actions[bot]' }, body }); writes.push('create'); },
    updateComment: async ({ comment_id, body }) => { assert.equal(comment_id, 2); comments[1].body = body; writes.push('update'); },
  } } };
  const announce = (registry, data = receipt, artifact = '456') => updateCard(github, { owner, repo, receipt: data, artifact, registry });
  assert.equal(await announce(), 'created');
  assert.equal(await announce(), 'unchanged');
  assert.equal(await announce({ npmjs: { available: true, next: true } }), 'updated');
  assert.equal(await announce(), 'preserved');
  assert.equal(await announce({ 'github-packages': { available: true, next: true } }), 'updated');
  assert.match(comments[1].body, /#### npmjs[\s\S]*An earlier dispatch verified these bytes/);
  assert.match(comments[1].body, /#### GitHub Packages[\s\S]*Registry readback observed `next`/);
  assert.equal(await announce({ 'github-packages': { available: true, next: true } }), 'unchanged');
  assert.equal(await announce({ 'github-packages': { available: true, next: true } }, { ...receipt, sha256: '0'.repeat(64) }, '457'), 'updated');
  assert.doesNotMatch(comments[1].body, /#### npmjs/);
  current = { ...prInfo, head: { ...prInfo.head, sha: 'b'.repeat(40) } };
  assert.equal(await announce(), 'stale');
  assert.deepEqual(writes, ['create', 'update', 'update', 'update']);
});

test('registry readback is bounded and never overwrites mismatched or stale previews', async () => {
  let elapsed = 0;
  let requests = 0;
  let reads = 0;
  let tagReads = 0;
  const options = { receipt, readExact: () => ++reads > 2 ? true : null, readNext: () => ++tagReads > 1,
    readLatest: () => '1.11.0', checkHead: () => {}, send: () => requests++,
    newBudget: () => createNpmObservationBudget({ timeoutMs: 50, intervalMs: 5, now: () => elapsed, sleep: async ms => { elapsed += ms; } }) };
  assert.deepEqual(await publishPreview(options), { available: true, next: true, request: 'accepted', observation: 'verified' });
  assert.equal(requests, 1);
  assert.deepEqual(await publishPreview({ ...options, readNext: () => false }),
    { available: true, next: false, request: 'existing', observation: 'tag-unverified' });
  await assert.rejects(publishPreview({ ...options, readExact: () => null, readLatest: () => '1.12.0' }), /must be newer/);
  await assert.rejects(publishPreview({ ...options, readExact: () => { throw new Error('conflicting digest'); } }), /conflicting digest/);
  await assert.rejects(publishPreview({ ...options, readExact: () => null, checkHead: () => { throw new Error('head changed'); } }), /head changed/);
  await assert.rejects(publishPreview({ ...options, receipt: { ...receipt, baseline: null } }), /no verified npm latest/);
  assert.equal(requests, 1);
  reads = 0;
  assert.deepEqual(await publishPreview({ ...options, readNext: () => false, send: () => { requests++; throw new Error('response lost'); } }),
    { available: true, next: false, request: 'unconfirmed', observation: 'tag-unverified' });
  assert.equal(requests, 2);
});

test('workflows isolate publishing and the two writers use the same non-replacing per-PR queue', () => {
  const ci = YAML.parse(readFileSync('.github/workflows/ci.yml', 'utf8'));
  const dispatch = YAML.parse(readFileSync('.github/workflows/pr-preview-publish.yml', 'utf8'));
  assert.deepEqual(Object.keys(dispatch.on), ['workflow_dispatch']);
  assert.match(dispatch.jobs.publish.if, /refs\/heads\/main.*PR_PREVIEW_PUBLISH_ENABLED/);
  assert.deepEqual(ci.permissions, { contents: 'read' });
  assert.equal(ci.jobs['pr-preview'].permissions, undefined);
  assert.equal(ci.jobs['pr-preview'].steps[0].with.ref, '${{ github.event.pull_request.head.sha }}');
  assert.match(ci.jobs['pr-preview-comment'].if, /head\.repo\.full_name == github\.repository/);
  assert.equal(ci.jobs['pr-preview-comment'].concurrency.queue, 'max');
  assert.equal(dispatch.jobs.announce.concurrency.queue, 'max');
  assert.match(ci.jobs['pr-preview-comment'].concurrency.group, /^idocs-pr-preview-card-/);
  assert.match(dispatch.jobs.announce.concurrency.group, /^idocs-pr-preview-card-/);
  assert.equal(dispatch.jobs.publish.steps[0].with.ref, '${{ github.workflow_sha }}');
  const download = dispatch.jobs.publish.steps.find(step => step.uses?.startsWith('actions/download-artifact@'));
  assert.equal(download.with['artifact-ids'], '${{ steps.source.outputs.artifact }}');
  assert.equal(download.with['merge-multiple'], true);
  assert.equal(dispatch.jobs.publish.permissions['id-token'], 'write');
  assert.equal(dispatch.jobs.announce.permissions['id-token'], undefined);
});
