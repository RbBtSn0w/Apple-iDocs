import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';

test('registries publish identical bytes, recover only missing targets, and reject conflicts/read errors', () => {
  const root = mkdtempSync(join(tmpdir(), 'idocs-registry-test-'));
  const tools = join(root, 'bin'); mkdirSync(tools);
  const stateFile = join(root, 'state.json');
  const logFile = join(root, 'calls.json');
  const native = join(root, 'idocs-darwin-arm64.tar.gz');
  const wrapper = join(root, 'package.tgz');
  writeFileSync(native, 'native archive'); writeFileSync(wrapper, 'wrapper');
  const integrity = 'sha512-' + createHash('sha512').update(readFileSync(wrapper)).digest('base64');
  writeFileSync(stateFile, '{}'); writeFileSync(logFile, '[]');
  writeFileSync(join(tools, 'gh'), `#!${process.execPath}\nconst fs=require('fs');if(process.argv.includes('--jq'))process.stdout.write('42');else process.stdout.write(fs.readFileSync(process.env.NATIVE));\n`, { mode: 0o755 });
  writeFileSync(join(tools, 'npm'), `#!${process.execPath}
const fs=require('fs'),a=process.argv.slice(2),s=JSON.parse(fs.readFileSync(process.env.STATE)),r=a[a.indexOf('--registry')+1];
if(a[0]==='view') {if(process.env.READ_ERROR){console.error('ECONNRESET');process.exit(1)} if(s[r])console.log(JSON.stringify(s[r]));else{console.error('E404');process.exit(1)}}
else if(a[0]==='publish') {const calls=JSON.parse(fs.readFileSync(process.env.CALLS));calls.push(r);fs.writeFileSync(process.env.CALLS,JSON.stringify(calls));if(r.includes('github')&&process.env.FAIL_GITHUB)process.exit(17);s[r]=process.env.INTEGRITY;fs.writeFileSync(process.env.STATE,JSON.stringify(s));}
else process.exit(99);
`, { mode: 0o755 });
  const code = `import {publishRegistries} from ${JSON.stringify(new URL('./registries.mjs', import.meta.url).href)};await publishRegistries(${JSON.stringify(root)},{candidate:'a',next:{version:'1.0.1',gitTag:'v1.0.1'}});`;
  const run = (extra = {}) => execFileSync(process.execPath, ['--input-type=module', '-e', code], { env: { ...process.env, PATH: tools + ':' + process.env.PATH, STATE: stateFile, CALLS: logFile, NATIVE: native, INTEGRITY: integrity, ...extra }, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 20000 });
  try {
    assert.throws(() => run({ FAIL_GITHUB: 'true' }));
    assert.equal(JSON.parse(readFileSync(join(root, 'registries.json'))).registries.npm, 'verified');
    run();
    const calls = JSON.parse(readFileSync(logFile));
    assert.equal(calls.filter((name) => name.includes('npmjs')).length, 1);
    assert.equal(calls.filter((name) => name.includes('github')).length, 2);
    run(); assert.deepEqual(JSON.parse(readFileSync(logFile)), calls);
    writeFileSync(stateFile, JSON.stringify({ 'https://registry.npmjs.org': 'different bytes' }));
    assert.throws(run); assert.deepEqual(JSON.parse(readFileSync(logFile)), calls);
    writeFileSync(stateFile, '{}'); assert.throws(() => run({ READ_ERROR: 'true' }));
    assert.deepEqual(JSON.parse(readFileSync(logFile)), calls);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
