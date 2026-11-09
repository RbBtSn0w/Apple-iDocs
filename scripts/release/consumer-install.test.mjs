import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import test from 'node:test';
import {verifyPackage} from './verify-package.mjs';

test('consumer verification executes the selected npm lifecycle with a package-scoped approval', async () => {
  const root = mkdtempSync(join(tmpdir(), 'idocs-npm-lifecycle-'));
  try {
    const pkg = join(root, 'package');
    mkdirSync(join(pkg, 'bin'), {recursive: true});
    mkdirSync(join(pkg, 'scripts'));
    writeFileSync(join(pkg, 'package.json'), JSON.stringify({name: '@rbbtsn0w/idocs', version: '1.2.3', type: 'module', scripts: {postinstall: 'node scripts/postinstall.mjs'}}));
    writeFileSync(join(pkg, 'README.md'), 'Synthetic lifecycle fixture');
    writeFileSync(join(pkg, 'scripts/postinstall.mjs'), `import {mkdirSync,writeFileSync} from 'node:fs';
if(process.env.npm_lifecycle_event!=='postinstall') throw Error('Must install through npm, not invoke the script directly');
mkdirSync('dist');writeFileSync('dist/idocs.version','1.2.3');`);
    writeFileSync(join(pkg, 'bin/idocs.js'), `import {readFileSync} from 'node:fs';
const version=readFileSync(new URL('../dist/idocs.version',import.meta.url),'utf8');console.log(process.argv.includes('--version')?version:'USAGE: synthetic idocs');`);
    const archive = join(root, 'package.tgz');
    execFileSync('tar', ['-czf', archive, '-C', root, 'package']);
    mkdirSync(join(root, 'idocs-darwin-arm64'));
    writeFileSync(join(root, 'idocs-darwin-arm64/idocs'), 'Synthetic unused native asset');
    const native = join(root, 'native.tgz');
    execFileSync('tar', ['-czf', native, '-C', root, 'idocs-darwin-arm64']);
    await assert.doesNotReject(verifyPackage(archive, native, '1.2.3'));
  } finally {rmSync(root, {recursive: true, force: true});}
});
