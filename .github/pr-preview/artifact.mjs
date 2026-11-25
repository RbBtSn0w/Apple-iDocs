import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { appendFileSync, copyFileSync, cpSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseNpmPack } from '../release-train/npm-pack.mjs';
import { fullSha, packageName, positiveId, previewVersion, readStableLatest, requireNewerPreview, stableCore } from './version.mjs';

export const tarballName = 'idocs-pr-preview.tgz';
const nativeName = 'idocs-darwin-arm64.tar.gz';
const installScript = 'node ./preview/install.mjs';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const integrity = bytes => 'sha512-' + createHash('sha512').update(bytes).digest('base64');
const json = path => JSON.parse(readFileSync(path, 'utf8'));

function identity(env) {
  const { PR_NUMBER: pr, PR_HEAD: head, SOURCE_RUN_ID: run, SOURCE_ATTEMPT: attempt } = env;
  if (![pr, run, attempt].every(value => typeof value === 'string' && positiveId.test(value)) || !fullSha.test(head)) {
    throw new Error('Invalid PR, head, run, or packaging attempt');
  }
  return { pr, head, run, attempt };
}

function tarEntry(archive, file, maxBuffer = 1024 * 1024) {
  return execFileSync('tar', ['-xOzf', archive, file], { maxBuffer, timeout: 60000 });
}

export function verifyArtifact(directory, env) {
  const expected = identity(env);
  const archive = join(directory, tarballName);
  const fileLimits = { [tarballName]: 128 * 1024 * 1024, 'receipt.json': 8192, SHA256SUMS: 256 };
  for (const [name, maxBytes] of Object.entries(fileLimits)) {
    const file = lstatSync(join(directory, name));
    if (!file.isFile() || file.size > maxBytes) throw new Error(`Invalid artifact file: ${name}`);
  }
  const receipt = json(join(directory, 'receipt.json'));
  for (const [field, value] of Object.entries(expected)) assert.equal(receipt[field], value, `Wrong preview ${field}`);
  assert.equal(receipt.name, packageName, 'Wrong preview package name');
  const { version, baseline } = receipt;
  assert.ok(typeof version === 'string' && version.endsWith(`-dev.pr${expected.pr}.g${expected.head}`), 'Wrong preview version identity');
  stableCore(version.split('-', 1)[0]);
  if (baseline !== null) requireNewerPreview(version, baseline);

  const bytes = readFileSync(archive);
  assert.equal(receipt.sha256, sha256(bytes), 'Wrong package checksum');
  assert.equal(receipt.integrity, integrity(bytes), 'Wrong package integrity');
  assert.equal(readFileSync(join(directory, 'SHA256SUMS'), 'utf8'), `${receipt.sha256}  ${tarballName}\n`, 'Wrong checksum file');
  const manifest = JSON.parse(tarEntry(archive, 'package/package.json'));
  assert.equal(manifest.name, packageName, 'Wrong tarball package name');
  assert.equal(manifest.version, version, 'Wrong tarball version');
  assert.deepEqual(manifest.bin, { idocs: 'bin/idocs.js' });
  assert.deepEqual(manifest.os, ['darwin']);
  assert.deepEqual(manifest.cpu, ['arm64']);
  assert.deepEqual(manifest.scripts, { postinstall: installScript });
  assert.deepEqual(manifest.publishConfig, { access: 'public', provenance: true });
  assert.equal(manifest.repository?.url, 'git+https://github.com/RbBtSn0w/Apple-iDocs.git');
  assert.deepEqual(tarEntry(archive, 'package/preview/install.mjs'), readFileSync(new URL('./install.mjs', import.meta.url)), 'Unexpected preview installer');
  assert.equal(sha256(tarEntry(archive, `package/preview/${nativeName}`, 96 * 1024 * 1024)), receipt.nativeSha256, 'Wrong native archive checksum');
  return receipt;
}

export function makePreview({ source, directory, env = process.env, lookupLatest = readStableLatest, smoke = smokeInstall }) {
  const binding = identity(env);
  assert.equal(execFileSync('git', ['rev-parse', 'HEAD'], { cwd: source, encoding: 'utf8' }).trim(), binding.head, 'Checkout is not the PR head');
  const manifest = json(join(source, 'npm/package.json'));
  assert.equal(manifest.name, packageName);
  let baseline = null;
  try {
    const latest = lookupLatest();
    stableCore(latest);
    baseline = latest;
  } catch (error) {
    console.warn(`::warning::${error.message}. This preview is available as an artifact only.`);
  }
  const version = previewVersion(manifest.version, baseline, binding.pr, binding.head);
  const temporary = mkdtempSync(join(tmpdir(), 'idocs-preview-pack-'));
  try {
    const native = join(temporary, 'native');
    const staging = join(temporary, 'wrapper');
    const bundled = join(staging, 'preview');
    mkdirSync(bundled, { recursive: true });
    execFileSync('bash', [join(source, 'scripts/release-package.sh'), version, native], { cwd: source, env, stdio: 'inherit' });
    const nativeArchive = join(native, nativeName);
    copyFileSync(nativeArchive, join(bundled, nativeName));
    copyFileSync(new URL('./install.mjs', import.meta.url), join(bundled, 'install.mjs'));
    cpSync(join(source, 'npm/bin'), join(staging, 'bin'), { recursive: true });
    copyFileSync(join(source, 'npm/README.md'), join(staging, 'README.md'));
    const { devDependencies, overrides, ...wrapper } = manifest;
    writeFileSync(join(staging, 'package.json'), JSON.stringify({ ...wrapper, version,
      scripts: { postinstall: installScript }, files: ['bin', 'preview', 'README.md'] }, null, 2) + '\n');
    const packed = parseNpmPack(execFileSync('npm', ['pack', '--ignore-scripts', '--json', '--pack-destination', temporary, '--cache', join(temporary, 'cache')],
      { cwd: staging, encoding: 'utf8' }), packageName);
    assert.equal(packed.version, version);
    mkdirSync(directory);
    const archive = join(directory, tarballName);
    copyFileSync(join(temporary, packed.filename), archive);
    const bytes = readFileSync(archive);
    const receipt = { ...binding, name: packageName, version, baseline, sha256: sha256(bytes), integrity: integrity(bytes),
      nativeSha256: sha256(readFileSync(nativeArchive)) };
    writeFileSync(join(directory, 'receipt.json'), JSON.stringify(receipt) + '\n');
    writeFileSync(join(directory, 'SHA256SUMS'), `${receipt.sha256}  ${tarballName}\n`);
    verifyArtifact(directory, env);
    smoke(archive, version);
    assert.equal(sha256(readFileSync(archive)), receipt.sha256, 'Package changed during installation smoke');
    return receipt;
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

export function smokeInstall(archive, version) {
  const cwd = mkdtempSync(join(tmpdir(), 'idocs-preview-consumer-'));
  try {
    const env = { ...process.env, NPM_CONFIG_USERCONFIG: join(cwd, 'user.npmrc'), NPM_CONFIG_GLOBALCONFIG: join(cwd, 'global.npmrc'),
      NPM_CONFIG_CACHE: join(cwd, 'npm-cache'), NPM_CONFIG_IGNORE_SCRIPTS: 'false', DISABLE_TELEMETRY: '1', DO_NOT_TRACK: '1',
      IDOCS_CACHE_PATH: join(cwd, 'idocs-cache'), IDOCS_USAGE_LOG_PATH: join(cwd, 'usage.jsonl') };
    for (const key of ['IDOCS_LOCAL_BINARY', 'IDOCS_CLI_VERSION', 'IDOCS_RELEASE_BASE_URL', 'DYLD_FRAMEWORK_PATH']) delete env[key];
    writeFileSync(join(cwd, 'package.json'), JSON.stringify({ private: true, allowScripts: { [`file:${archive}`]: true } }));
    execFileSync('npm', ['install', '--offline', '--no-audit', '--no-fund', '--foreground-scripts', archive], { cwd, env, stdio: 'inherit', timeout: 60000 });
    const idocs = join(cwd, 'node_modules/.bin/idocs');
    const run = (...args) => execFileSync(idocs, args, { cwd, env, encoding: 'utf8', timeout: 30000 });
    assert.equal(run('--version').trim(), version);
    assert.match(run('--help'), /USAGE: idocs/);
    assert.match(run('resolve', '--help'), /--framework/);
    console.log(`Installed iDocs ${version} passed version, help and resolve help.`);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
}

if (import.meta.main) {
  const [command, path, source = '.'] = process.argv.slice(2);
  const directory = resolve(path);
  if (command === 'build') {
    const receipt = makePreview({ source: resolve(source), directory });
    if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `receipt=${JSON.stringify(receipt)}\n`);
  } else if (command === 'verify') {
    console.log(JSON.stringify(verifyArtifact(directory, process.env)));
  } else if (command === 'smoke') {
    const receipt = json(join(directory, 'receipt.json'));
    smokeInstall(join(directory, tarballName), receipt.version);
  } else {
    throw new Error('Expected build, verify, or smoke');
  }
}
