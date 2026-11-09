import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, isAbsolute, join } from 'node:path';

export function extract(archive, destination, prefix) {
  const names = execFileSync('tar', ['-tzf', archive], { encoding: 'utf8' }).trim().split('\n');
  if (!names.length || names.some((name) => !name.startsWith(prefix + '/') || name.split('/').includes('..') || name.includes('\\'))) throw new Error('Unsafe archive path');
  const listing = execFileSync('tar', ['-tvzf', archive], { encoding: 'utf8' }).trim().split('\n');
  // Framework symlinks are part of the signed/native bundle. Reject unsafe targets before extraction.
  for (const entry of listing) {
    if (!['-', 'd', 'l'].includes(entry[0])) throw new Error('Unsafe archive entry type');
    if (entry[0] === 'l') {
      const target = entry.split(' -> ')[1];
      if (!target || isAbsolute(target) || target.split('/').includes('..')) throw new Error('Unsafe archive link');
    }
  }
  execFileSync('tar', ['-xzf', archive, '-C', destination]);
}

export async function cleanupConsumer(server, temporary) {
  try {
    if (server.listening) {
      await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
  } finally { rmSync(temporary, { recursive: true, force: true }); }
}

export async function verifyPackage(tarball, nativeArchive, version) {
  if (![tarball, nativeArchive].every(isAbsolute) || !/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Absolute archive paths and stable version required');
  const before = createHash('sha256').update(readFileSync(tarball)).digest('hex');
  const temporary = mkdtempSync(join(tmpdir(), 'idocs-consumer-'));
  const server = createServer((request, response) => {
    if (request.url !== `/v${version}/idocs-darwin-arm64.tar.gz`) { response.writeHead(404).end(); return; }
    response.end(readFileSync(nativeArchive));
  });
  try {
    extract(tarball, temporary, 'package');
    const packageRoot = join(temporary, 'package');
    const pkg = JSON.parse(readFileSync(join(packageRoot, 'package.json')));
    assert.equal(pkg.name, '@rbbtsn0w/idocs'); assert.equal(pkg.version, version);
    for (const file of ['bin/idocs.js', 'scripts/postinstall.mjs', 'README.md']) assert.ok(lstatSync(join(packageRoot, file)).isFile());
    assert.deepEqual(readdirSync(packageRoot).sort(), ['README.md', 'bin', 'package.json', 'scripts']);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const consumer = join(temporary, 'consumer');
    mkdirSync(consumer);
    writeFileSync(join(consumer, 'package.json'), JSON.stringify({private: true, allowScripts: {[`file:${tarball}`]: true}}));
    const env = { ...process.env, NPM_CONFIG_IGNORE_SCRIPTS: 'false', IDOCS_RELEASE_BASE_URL: `http://127.0.0.1:${server.address().port}/v{version}`, IDOCS_NPM_STRICT_INSTALL: '1', DISABLE_TELEMETRY: '1', DO_NOT_TRACK: '1', IDOCS_CACHE_PATH: join(temporary, 'cache'), IDOCS_USAGE_LOG_PATH: join(temporary, 'usage.jsonl') };
    delete env.IDOCS_LOCAL_BINARY; delete env.IDOCS_CLI_VERSION;
    // Spawn asynchronously: the parent must serve the real installer's local HTTP request.
    const { spawn } = await import('node:child_process');
    await new Promise((resolve, reject) => {
      const child = spawn('npm', ['install', '--no-audit', '--no-fund', '--foreground-scripts', tarball], { env, cwd: consumer, stdio: 'inherit' });
      child.on('error', reject); child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`Wrapper installer failed: ${code}`)));
    });
    const installedRoot = join(consumer, 'node_modules/@rbbtsn0w/idocs');
    const run = (...args) => execFileSync(process.execPath, [join(installedRoot, 'bin/idocs.js'), ...args], { env, cwd: consumer, encoding: 'utf8', timeout: 30000 });
    assert.equal(run('--version').trim(), version);
    assert.match(run('--help'), /USAGE:/);
    assert.equal(readFileSync(join(installedRoot, 'dist/idocs.version'), 'utf8').trim(), version);
    assert.equal(createHash('sha256').update(readFileSync(tarball)).digest('hex'), before);
  } finally { await cleanupConsumer(server, temporary); }
}

if (process.argv[1] && basename(process.argv[1]) === 'verify-package.mjs') {
  verifyPackage(...process.argv.slice(2)).catch((error) => { console.error(error); process.exitCode = 1; });
}
