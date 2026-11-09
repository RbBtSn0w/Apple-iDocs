import {registryState} from './registries.mjs';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';

for (const npmMajor of ['11', '12']) {
test(`npm ${npmMajor}: registries publish identical bytes, recover only missing targets, and reject conflicts/read errors`, () => {
  const root = mkdtempSync(join(tmpdir(), 'idocs-registry-test-'));
  const tools = join(root, 'bin'); mkdirSync(tools);
  const stateFile = join(root, 'state.json');
  const logFile = join(root, 'calls.json');
  const native = join(root, 'idocs-darwin-arm64.tar.gz');
  const wrapper = join(root, 'package.tgz');
  writeFileSync(native, 'native archive'); writeFileSync(wrapper, 'wrapper');
  const integrity = 'sha512-' + createHash('sha512').update(readFileSync(wrapper)).digest('base64');
  writeFileSync(stateFile, '{}'); writeFileSync(logFile, '[]');
  writeFileSync(join(tools, 'gh'), `#!${process.execPath}\nconst fs=require('fs');if(process.argv.some(a=>a.includes('/actions/artifacts?name=')))console.log(JSON.stringify([{artifacts:process.argv.some(a=>a.includes('name=release-recovery-intent-12-34&'))?[]:[{id:78,name:process.argv.find(a=>a.includes('/actions/artifacts?name=')).split('name=')[1].split('&')[0],expired:false,workflow_run:{id:56}}]}]));else if(process.argv.includes('--jq'))process.stdout.write('42');else process.stdout.write(fs.readFileSync(process.env.NATIVE));\n`, { mode: 0o755 });
  writeFileSync(join(tools, 'npm'), `#!${process.execPath}
const log=console.log;console.log=value=>log(${npmMajor === '12'}?JSON.stringify([JSON.parse(value)]):value);
const fs=require('fs'),a=process.argv.slice(2),s=JSON.parse(fs.readFileSync(process.env.STATE)),r=a[a.indexOf('--registry')+1];
if(a[0]==='view'&&a[2]==='dist-tags'){if(process.env.READ_TAG_ERROR){console.error('ECONNRESET');process.exit(1)}console.log(JSON.stringify(s['tags:'+r]||{latest:process.env.LATEST_VERSION||'1.0.1'}));}
else if(a[0]==='dist-tag'&&a[1]==='add'){const tags=s['tags:'+r]||{};tags[a[3]]=a[2].split('@').at(-1);s['tags:'+r]=tags;fs.writeFileSync(process.env.STATE,JSON.stringify(s));}
else if(a[0]==='dist-tag'&&a[1]==='rm'){const tags=s['tags:'+r]||{};delete tags[a[3]];s['tags:'+r]=tags;fs.writeFileSync(process.env.STATE,JSON.stringify(s));}
else if(a[0]==='view') {if(process.env.READ_ERROR){console.error('ECONNRESET');process.exit(1)} if(s[r])console.log(JSON.stringify(s[r]));else{console.log(JSON.stringify({error:{code:'E404'}}));console.error('E404');process.exit(1)}}
else if(a[0]==='publish') {const calls=JSON.parse(fs.readFileSync(process.env.CALLS));calls.push(r);fs.writeFileSync(process.env.CALLS,JSON.stringify(calls));if(r.includes('github')&&process.env.FAIL_GITHUB)process.exit(17);s[r]=process.env.INTEGRITY;const tags=s['tags:'+r]||{latest:process.env.LATEST_VERSION||'1.0.1'};tags[a[a.indexOf('--tag')+1]]='1.0.1';s['published:'+r]=a[a.indexOf('--tag')+1];s['tags:'+r]=tags;fs.writeFileSync(process.env.STATE,JSON.stringify(s));}
else process.exit(99);
`, { mode: 0o755 });
  const code = `import {publishRegistries} from ${JSON.stringify(new URL('./registries.mjs', import.meta.url).href)};let attempts=0;const observationBudget={assertRemaining(){if(attempts>=5)throw Error('Observation budget exhausted');return 60000;},async wait(read){while(true){this.assertRemaining();const value=await read(60000);attempts++;if(value!==null)return value;}}};await publishRegistries(${JSON.stringify(root)},{candidate:'a',next:{version:'1.0.1',gitTag:'v1.0.1'}},{recovery:process.env.RECOVERY==='true',observationBudget});`;
  const run = (extra = {}) => execFileSync(process.execPath, ['--input-type=module', '-e', code], { env: { ...process.env, PATH: tools + ':' + process.env.PATH, STATE: stateFile, CALLS: logFile, NATIVE: native, INTEGRITY: integrity,GITHUB_REPOSITORY:'owner/repo',GITHUB_RUN_ID:'56',SOURCE_RUN_ID:'12',ARTIFACT_ID:'34',RECOVERY_INTENT_ARTIFACT_ID:'78', ...extra }, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 20000 });
  try {
    assert.throws(() => run({ FAIL_GITHUB: 'true' }));
    assert.equal(JSON.parse(readFileSync(join(root, 'registries.json'))).registries.npm, 'verified');
    assert.equal(JSON.parse(readFileSync(join(root, 'registries.json'))).registries.github, 'unknown');
    assert.throws(run, /Observation budget exhausted/);
    assert.equal(JSON.parse(readFileSync(logFile)).filter(name=>name.includes('github')).length,1);
    // A lost response may have been accepted; simulate later visibility without another request.
    const visible=JSON.parse(readFileSync(stateFile));visible['https://npm.pkg.github.com']=integrity;writeFileSync(stateFile,JSON.stringify(visible));
    run();
    const calls = JSON.parse(readFileSync(logFile));
    const receipt = JSON.parse(readFileSync(join(root, 'registries.json')));
    assert.equal(receipt.receipts.npm.integrity, integrity);
    assert.equal(receipt.receipts.npm.status, 'completed');
    assert.ok(Number.isFinite(Date.parse(receipt.receipts.npm.observed_at)));
    assert.equal(calls.filter((name) => name.includes('npmjs')).length, 1);
    assert.equal(calls.filter((name) => name.includes('github')).length, 1);
    run(); assert.deepEqual(JSON.parse(readFileSync(logFile)), calls);
    writeFileSync(stateFile, JSON.stringify({ 'https://registry.npmjs.org': 'different bytes' }));
    assert.throws(run); assert.deepEqual(JSON.parse(readFileSync(logFile)), calls);
    writeFileSync(stateFile, '{}'); assert.throws(() => run({ READ_ERROR: 'true' }));
    assert.deepEqual(JSON.parse(readFileSync(logFile)), calls);
    writeFileSync(stateFile, '{}');
    assert.throws(() => run({RECOVERY: 'true', READ_TAG_ERROR: 'true'}));
    assert.deepEqual(JSON.parse(readFileSync(logFile)), calls);
    for (const latest of [undefined, '0.9.0', '1.0.1', '2.0.0']) {
      writeFileSync(join(root,'registries.json'),JSON.stringify({receipts:Object.fromEntries(['npm','github'].map(name=>[name,{candidate_sha:'a',version:'1.0.1',integrity,status:'not-run'}]))}));
      writeFileSync(stateFile, JSON.stringify(latest===undefined?{'tags:https://registry.npmjs.org':{},'tags:https://npm.pkg.github.com':{}}:{}));
      if(latest===undefined||latest==='0.9.0')assert.throws(()=>run({RECOVERY:'true',LATEST_VERSION:latest}));
      else run({RECOVERY: 'true', LATEST_VERSION: latest});
      const recovered = JSON.parse(readFileSync(stateFile));
      for (const registry of ['https://registry.npmjs.org', 'https://npm.pkg.github.com']) {
        assert.equal(recovered['tags:'+registry].latest, latest);
        assert.ok(Object.keys(recovered['tags:'+registry]).some(tag=>tag.startsWith('idocs-recovery-')));
        if(latest!==undefined&&latest!=='0.9.0'){const evidence=JSON.parse(readFileSync(join(root,'registries.json'))).receipts[registry.includes('npmjs')?'npm':'github'];assert.equal(evidence.latest_version,latest);assert.ok(Number.isFinite(Date.parse(evidence.channel_observed_at)));}
        assert.match(recovered['published:'+registry], /^idocs-recovery-/);
      }
    }

  } finally { rmSync(root, { recursive: true, force: true }); }
});

}


test('npm error output must be one structured E404 observation before authorizing absent-package publication', () => {
 const root=mkdtempSync(join(tmpdir(),'idocs-npm-error-')),bin=join(root,'bin');mkdirSync(bin);
 writeFileSync(join(bin,'npm'),`#!${process.execPath}
console.log(process.env.ERROR_JSON);console.error('npm error code E404');process.exit(1);
`,{mode:0o755});
 const state=value=>registryState('https://registry.npmjs.org','1.0.1',{...process.env,PATH:bin+':'+process.env.PATH,ERROR_JSON:JSON.stringify(value)});
 try {
  for(const value of [{error:{code:'E404'}},[{error:{code:'E404'}}]])assert.equal(state(value),null);
  for(const value of [[],[[{error:{code:'E404'}}]],[{error:{code:'E404'}},{error:{code:'E401'}}],{error:{code:'E401'}}])assert.throws(()=>state(value),/Cannot inspect registry/);
 } finally {rmSync(root,{recursive:true,force:true});}
});
