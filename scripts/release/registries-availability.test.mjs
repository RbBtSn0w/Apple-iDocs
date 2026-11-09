import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';

function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'idocs-availability-')), bin = join(root, 'bin');
  mkdirSync(bin);
  writeFileSync(join(root, 'package.tgz'), 'wrapper');
  writeFileSync(join(root, 'idocs-darwin-arm64.tar.gz'), 'native');
  const integrity = 'sha512-' + createHash('sha512').update('wrapper').digest('base64');
  writeFileSync(join(bin, 'gh'), `#!${process.execPath}\nif(process.argv.some(a=>a.includes('/actions/artifacts?name=')))console.log(JSON.stringify([{artifacts:process.argv.some(a=>a.includes('name=release-recovery-intent-12-34&'))?[]:[{id:78,name:process.argv.find(a=>a.includes('/actions/artifacts?name=')).split('name=')[1].split('&')[0],expired:false,workflow_run:{id:56}}]}]));else process.stdout.write(process.argv.includes('--jq')?'42':'native');`, {mode:0o755});
  writeFileSync(join(bin, 'npm'), `#!${process.execPath}
const fs=require('fs'),p=require('path'),a=process.argv.slice(2),r=a[a.indexOf('--registry')+1],f=p.join(process.env.FIXTURE,'state.json');
const s=fs.existsSync(f)?JSON.parse(fs.readFileSync(f)):{};
const save=()=>fs.writeFileSync(f,JSON.stringify(s));
if(a[0]==='publish'){
 const receipt=JSON.parse(fs.readFileSync(p.join(process.env.FIXTURE,'registries.json'))).receipts[r.includes('npmjs')?'npm':'github'];
 if(receipt?.status!=='unknown'||receipt?.version!=='1.0.1'||receipt?.candidate_sha!=='original'||receipt?.publication_accepted===true||!Number.isFinite(Date.parse(receipt?.request_started_at)))process.exit(42);
 s['publish:'+r]=(s['publish:'+r]||0)+1;save();
 if(process.env.MODE==='upload-error')process.exit(17);
}else if(a[2]==='dist-tags'){
 s['tags:'+r]=(s['tags:'+r]||0)+1;save();
 console.log(JSON.stringify({latest:process.env.MODE==='ready-channel'||s['tags:'+r]>8?'1.0.1':'0.9.0'}));
}else{
 s['bytes:'+r]=(s['bytes:'+r]||0)+1;save();
 if(process.env.MODE==='malformed-bytes'){console.log('null');process.exit(0);}
 if(process.env.MODE==='auth-error'){console.log(JSON.stringify({error:{code:'E401'}}));process.exit(1);}
 if((process.env.MODE==='visible-preflight'&&s['bytes:'+r]===1)||s['bytes:'+r]>8)console.log(JSON.stringify(process.env.INTEGRITY));
 else {console.log(JSON.stringify({error:{code:'E404'}}));process.exit(1);}
}`, {mode:0o755});
  const code = `import {publishRegistries} from ${JSON.stringify(new URL('./registries.mjs', import.meta.url).href)};
let remaining=Number(process.env.STEPS||100);const observationBudget={remaining:()=>remaining*1000,assertRemaining(){if(remaining<=0)throw Error('budget exhausted');return remaining*1000;},async wait(read){while(true){this.assertRemaining();const value=await read(remaining*1000);remaining--;if(value!==null)return value;}}};
await publishRegistries(${JSON.stringify(root)},{candidate:'original',next:{version:'1.0.1',gitTag:'v1.0.1'}},{observationBudget,recovery:process.env.RECOVERY==='true',target:process.env.TARGET,preflight:process.env.PREFLIGHT==='true'});`;
  return {root, integrity, run(extra={}) {return execFileSync(process.execPath, ['--input-type=module','-e',code], {env:{...process.env,PATH:bin+':'+process.env.PATH,FIXTURE:root,INTEGRITY:integrity,GITHUB_REPOSITORY:'owner/repo',GITHUB_RUN_ID:'56',SOURCE_RUN_ID:'12',ARTIFACT_ID:'34',RECOVERY_INTENT_ARTIFACT_ID:'78',...extra},encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:15000});}, receipt(){return JSON.parse(readFileSync(join(root,'registries.json')));}, clean(){rmSync(root,{recursive:true,force:true});}};
}

test('delayed package bytes and channel settle beyond six observations on both registries', () => {
 const f=fixture();try {f.run();const receipt=f.receipt();for(const name of ['npm','github']){assert.equal(receipt.receipts[name].status,'completed');assert.equal(receipt.receipts[name].latest_version,'1.0.1');assert.equal(receipt.receipts[name].publication_accepted,true);}}finally{f.clean();}
});
test('failed upload retains the original unknown identity without accepted evidence', () => {
 const f=fixture();try {assert.throws(()=>f.run({MODE:'upload-error'}));const r=f.receipt().receipts.npm;assert.equal(r.status,'unknown');assert.equal(r.candidate_sha,'original');assert.equal(r.version,'1.0.1');assert.notEqual(r.publication_accepted,true);assert.equal(r.accepted_at,undefined);assert.ok(Number.isFinite(Date.parse(r.request_started_at)));}finally{f.clean();}
});
test('one shared observation budget prevents a later registry upload after exhaustion', () => {
 const f=fixture();try {assert.throws(()=>f.run({STEPS:'16'}));const s=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(s['publish:https://npm.pkg.github.com'],undefined);assert.equal(f.receipt().receipts.npm.status,'completed');assert.equal(f.receipt().registries.github,'not-run');assert.equal(f.receipt().receipts.github.status,'not-run');}finally{f.clean();}
});

for (const mode of ['malformed-bytes', 'auth-error']) {
 test(`${mode} fails immediately without an upload or repeated observation`, () => {
  const f=fixture();try {assert.throws(()=>f.run({MODE:mode}));const s=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(s['bytes:https://registry.npmjs.org'],1);assert.equal(s['publish:https://registry.npmjs.org'],undefined);assert.equal(f.receipt().receipts.npm.status,'not-run');}finally{f.clean();}
 });
}

test('recovery observes a lagging channel once without retrying or rewriting latest', () => {
 const f=fixture();try {writeFileSync(join(f.root,'registries.json'),JSON.stringify({receipts:Object.fromEntries(['npm','github'].map(name=>[name,{candidate_sha:'original',version:'1.0.1',integrity:f.integrity,status:'not-run'}]))}));assert.throws(()=>f.run({RECOVERY:'true'}));const s=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(s['tags:https://registry.npmjs.org'],2);const r=f.receipt().receipts.npm;assert.equal(r.status,'unknown');assert.equal(r.bytes_verified,true);assert.equal(r.publication_accepted,true);}finally{f.clean();}
});


test('original accepted or uncertain requests are observed through recovery without another upload', () => {
 for(const accepted of [true,false]){
  const f=fixture();try {
   const identity={candidate_sha:'original',version:'1.0.1',integrity:f.integrity};
   writeFileSync(join(f.root,'registries.json'),JSON.stringify({receipts:{npm:{...identity,status:'unknown',request_started_at:'2026-11-09T01:00:00Z',...(accepted?{publication_accepted:true,accepted_at:'2026-11-09T01:00:00Z'}:{})},github:{...identity,status:'not-run'}}}));
   f.run({RECOVERY:'true',MODE:'ready-channel'});
   const state=JSON.parse(readFileSync(join(f.root,'state.json')));
   assert.equal(state['publish:https://registry.npmjs.org'],undefined);
   assert.equal(state['publish:https://npm.pkg.github.com'],1);
   const receipt=f.receipt().receipts.npm;assert.equal(receipt.status,'completed');assert.equal(receipt.request_started_at,'2026-11-09T01:00:00Z');assert.equal(receipt.publication_accepted,accepted?true:undefined);assert.equal(receipt.accepted_at,accepted?'2026-11-09T01:00:00Z':undefined);
  }finally{f.clean();}
 }
});
test('legacy recovery with no request evidence remains unknown without an upload', () => {
 const f=fixture();try{
  assert.throws(()=>f.run({RECOVERY:'true'}),/original request evidence/);
  const state=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(state['publish:https://registry.npmjs.org'],undefined);assert.equal(f.receipt().receipts.npm.status,'unknown');
 }finally{f.clean();}
});

test('a failed channel recheck preserves request facts without historical channel evidence', () => {
 const f=fixture();try{
  const identity={candidate_sha:'original',version:'1.0.1',integrity:f.integrity};
  writeFileSync(join(f.root,'registries.json'),JSON.stringify({receipts:{npm:{...identity,status:'completed',request_started_at:'2026-11-09T01:00:00Z',publication_accepted:true,accepted_at:'2026-11-09T01:01:00Z',latest_version:'1.0.1',channel_observed_at:'2026-11-09T01:02:00Z'},github:{...identity,status:'not-run'}}}));
  assert.throws(()=>f.run({RECOVERY:'true'}),/channel/);
  const receipt=f.receipt().receipts.npm;assert.equal(receipt.status,'unknown');assert.equal(receipt.publication_accepted,true);assert.equal(receipt.request_started_at,'2026-11-09T01:00:00Z');assert.equal(receipt.latest_version,undefined);assert.equal(receipt.channel_observed_at,undefined);
 }finally{f.clean();}
});

test('failed read-only preflight preserves explicit not-run on both targets', () => {
 const f=fixture();try {
  const receipts=Object.fromEntries(['npm','github'].map(name=>[name,{candidate_sha:'original',version:'1.0.1',integrity:f.integrity,status:'not-run',bytes_verified:false}]));
  writeFileSync(join(f.root,'registries.json'),JSON.stringify({receipts}));
  assert.throws(()=>f.run({MODE:'auth-error'}));
  assert.deepEqual(f.receipt().receipts,receipts);
 }finally{f.clean();}
});

test('an accepted invisible public target leaves GitHub eligible for a later target preflight', () => {
 const f=fixture();try {
  const receipts=Object.fromEntries(['npm','github'].map(name=>[name,{candidate_sha:'original',version:'1.0.1',integrity:f.integrity,status:'not-run',bytes_verified:false}]));
  writeFileSync(join(f.root,'registries.json'),JSON.stringify({receipts}));
  assert.throws(()=>f.run({RECOVERY:'true',TARGET:'npm',MODE:'invisible',STEPS:'2'}),/budget/);
  const receipt=f.receipt();
  assert.equal(receipt.receipts.npm.publication_accepted,true);
  assert.ok(Number.isFinite(Date.parse(receipt.receipts.npm.accepted_at)));
  assert.deepEqual(receipt.receipts.github,receipts.github);
  const output=join(f.root,'output');
  f.run({RECOVERY:'true',TARGET:'github-packages',PREFLIGHT:'true',GITHUB_OUTPUT:output});
  assert.equal(readFileSync(output,'utf8'),'request_needed=true\n');
  assert.deepEqual(f.receipt(),receipt);
  assert.equal(JSON.parse(readFileSync(join(f.root,'state.json')))['publish:https://npm.pkg.github.com'],undefined);
 }finally{f.clean();}
});

test('target preflight never writes an intent or mutates request evidence on invalid registry reads', () => {
 const f=fixture();try {
  const receipts={npm:{candidate_sha:'original',version:'1.0.1',integrity:f.integrity,status:'not-run'}};
  writeFileSync(join(f.root,'registries.json'),JSON.stringify({receipts}));
  const output=join(f.root,'output');
  assert.throws(()=>f.run({RECOVERY:'true',TARGET:'npm',PREFLIGHT:'true',MODE:'auth-error',GITHUB_OUTPUT:output}));
  assert.deepEqual(f.receipt(),{receipts});
  assert.throws(()=>readFileSync(output));
 }finally{f.clean();}
});

test('recovery workflow brackets every target request with its preflight and conditional native marker', () => {
 const workflow=readFileSync(new URL('../../.github/workflows/release.yml',import.meta.url),'utf8');
 let previous=workflow.indexOf('RECOVERY_PHASE=prepare');
 assert.ok(previous>0);
 for(const [target,id] of [['npm','npm'],['github-packages','github_packages']]){
  const preflight=workflow.indexOf(`- name: Preflight recovery ${target}`);
  const marker=workflow.indexOf(`- name: Preserve immutable ${target} request intent`);
  const publish=workflow.indexOf(`- name: Publish or observe recovery ${target}`);
  assert.ok(previous<preflight && preflight<marker && marker<publish);
  const block=workflow.slice(marker,publish);
  assert.match(block,new RegExp(`steps.recovery_preflight_${id}.outputs.request_needed == 'true'`));
  assert.match(block,/uses: actions\/upload-artifact@v4/);
  assert.ok(block.includes(`name: release-recovery-intent-\${{ inputs.source_run_id }}-${target}`));
  previous=publish;
 }
 assert.ok(previous<workflow.indexOf('- name: Finalize verified recovery targets'));
 assert.doesNotMatch(workflow.split('  release:')[1].split('  publish-homebrew:')[0],/continue-on-error/);
 assert.match(workflow,/released: \$\{\{ steps.recovery_finalize.outputs.released \|\| steps.publish.outputs.released \}\}/);
 assert.match(workflow,/needs.release.outputs.released == 'true'/);
});

test('failed recovery preflight invalidates completed observation while preserving accepted request facts', () => {
 const f=fixture();try {
  const metadata={candidate_sha:'original',version:'1.0.1',integrity:f.integrity};
  const facts={request_started_at:'2026-11-09T01:00:00Z',publication_accepted:true,accepted_at:'2026-11-09T01:01:00Z'};
  const github={...metadata,status:'not-run'};
  writeFileSync(join(f.root,'registries.json'),JSON.stringify({registries:{npm:'verified',github:'not-run'},receipts:{npm:{...metadata,...facts,status:'completed',bytes_verified:true,channel_blocked:false,latest_version:'1.0.1',channel_observed_at:'2026-11-09T01:02:00Z'},github}}));
  assert.throws(()=>f.run({RECOVERY:'true',TARGET:'npm',PREFLIGHT:'true',MODE:'auth-error'}));
  const receipt=f.receipt();
  assert.equal(receipt.registries.npm,'unknown');
  assert.deepEqual(receipt.receipts.npm,{...metadata,...facts,status:'unknown',bytes_verified:false});
  assert.deepEqual(receipt.receipts.github,github);
  assert.equal(JSON.parse(readFileSync(join(f.root,'state.json')))['publish:https://registry.npmjs.org'],undefined);
 }finally{f.clean();}
});


test('matching preflight bytes survive a temporary E404 without a recovery intent or upload',()=>{
 const f=fixture();try{
  const identity={candidate_sha:'original',version:'1.0.1',integrity:f.integrity};
  writeFileSync(join(f.root,'registries.json'),JSON.stringify({receipts:{npm:{...identity,status:'not-run'}}}));
  f.run({RECOVERY:'true',PREFLIGHT:'true',TARGET:'npm',MODE:'visible-preflight',RECOVERY_INTENT_ARTIFACT_ID:''});
  assert.equal(f.receipt().receipts.npm.status,'unknown');assert.equal(f.receipt().receipts.npm.bytes_verified,true);
  f.run({RECOVERY:'true',TARGET:'npm',MODE:'ready-channel',RECOVERY_INTENT_ARTIFACT_ID:''});
  const state=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(state['publish:https://registry.npmjs.org'],undefined);assert.equal(f.receipt().receipts.npm.status,'completed');
 }finally{f.clean();}
});
