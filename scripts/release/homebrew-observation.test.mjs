import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import test from 'node:test';
const script = resolve('scripts/release/observe-homebrew.mjs');
test('tap readback confirms exact bytes or preserved newer version and rejects conflicts', () => {
  for (const [version, hash, accepted] of [['1.2.3','a',true],['1.3.0','b',true],['1.2.2','a',false],['1.2.3','b',false]]) {
    const cwd = mkdtempSync(join(tmpdir(),'tap-readback-'));
    try {
      mkdirSync(join(cwd,'bin'));
      writeFileSync(join(cwd,'bin/gh'),`#!${process.execPath}\nconsole.log(JSON.stringify({sha:'b'.repeat(40),content:Buffer.from(process.env.FORMULA).toString('base64'),html_url:'https://example.invalid/tap/Formula/idocs.rb'}));\n`,{mode:0o755});
      const result = spawnSync(process.execPath,[script],{cwd,encoding:'utf8',env:{...process.env,PATH:join(cwd,'bin')+':'+process.env.PATH,FORMULA:`  version "${version}"\n  sha256 "${hash.repeat(64)}"\n`,GITHUB_REPOSITORY:'example/idocs',RELEASE_VERSION:'1.2.3',RELEASE_CANDIDATE:'a'.repeat(40),RELEASE_NATIVE_SHA256:'a'.repeat(64),HOMEBREW_TAP_REPOSITORY:'example/tap'}});
      assert.equal(result.status===0,accepted,result.stderr);
      if(accepted){const receipt=JSON.parse(readFileSync(join(cwd,'homebrew-receipt.json')));assert.equal(receipt.status,version==='1.2.3'?'completed':'unknown');assert.equal(receipt.remote_version,version);assert.equal(receipt.preserved_newer,version!=='1.2.3');assert.ok(Number.isFinite(Date.parse(receipt.observed_at)));}
    } finally {rmSync(cwd,{recursive:true,force:true});}
  }
});
