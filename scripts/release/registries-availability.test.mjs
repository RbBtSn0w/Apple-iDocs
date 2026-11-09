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
  writeFileSync(join(bin, 'gh'), `#!${process.execPath}\nprocess.stdout.write(process.argv.includes('--jq')?'42':'native');`, {mode:0o755});
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
 console.log(JSON.stringify({latest:s['tags:'+r]>8?'1.0.1':'0.9.0'}));
}else{
 s['bytes:'+r]=(s['bytes:'+r]||0)+1;save();
 if(process.env.MODE==='malformed-bytes'){console.log('null');process.exit(0);}
 if(process.env.MODE==='auth-error'){console.log(JSON.stringify({error:{code:'E401'}}));process.exit(1);}
 if(s['bytes:'+r]>8)console.log(JSON.stringify(process.env.INTEGRITY));
 else {console.log(JSON.stringify({error:{code:'E404'}}));process.exit(1);}
}`, {mode:0o755});
  const code = `import {publishRegistries} from ${JSON.stringify(new URL('./registries.mjs', import.meta.url).href)};
let remaining=Number(process.env.STEPS||100);const observationBudget={remaining:()=>remaining*1000,assertRemaining(){if(remaining<=0)throw Error('budget exhausted');return remaining*1000;},async wait(read){while(true){this.assertRemaining();const value=await read(remaining*1000);remaining--;if(value!==null)return value;}}};
await publishRegistries(${JSON.stringify(root)},{candidate:'original',next:{version:'1.0.1',gitTag:'v1.0.1'}},{observationBudget,recovery:process.env.RECOVERY==='true'});`;
  return {root, run(extra={}) {return execFileSync(process.execPath, ['--input-type=module','-e',code], {env:{...process.env,PATH:bin+':'+process.env.PATH,FIXTURE:root,INTEGRITY:integrity,...extra},encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:15000});}, receipt(){return JSON.parse(readFileSync(join(root,'registries.json')));}, clean(){rmSync(root,{recursive:true,force:true});}};
}

test('delayed package bytes and channel settle beyond six observations on both registries', () => {
 const f=fixture();try {f.run();const receipt=f.receipt();for(const name of ['npm','github']){assert.equal(receipt.receipts[name].status,'completed');assert.equal(receipt.receipts[name].latest_version,'1.0.1');assert.equal(receipt.receipts[name].publication_accepted,true);}}finally{f.clean();}
});
test('failed upload retains the original unknown identity without accepted evidence', () => {
 const f=fixture();try {assert.throws(()=>f.run({MODE:'upload-error'}));const r=f.receipt().receipts.npm;assert.equal(r.status,'unknown');assert.equal(r.candidate_sha,'original');assert.equal(r.version,'1.0.1');assert.notEqual(r.publication_accepted,true);assert.equal(r.accepted_at,undefined);assert.ok(Number.isFinite(Date.parse(r.request_started_at)));}finally{f.clean();}
});
test('one shared observation budget prevents a later registry upload after exhaustion', () => {
 const f=fixture();try {assert.throws(()=>f.run({STEPS:'16'}));const s=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(s['publish:https://npm.pkg.github.com'],undefined);assert.equal(f.receipt().receipts.npm.status,'completed');assert.equal(f.receipt().registries.github,'not-run');assert.equal(f.receipt().receipts.github,undefined);}finally{f.clean();}
});

for (const mode of ['malformed-bytes', 'auth-error']) {
 test(`${mode} fails immediately without an upload or repeated observation`, () => {
  const f=fixture();try {assert.throws(()=>f.run({MODE:mode}));const s=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(s['bytes:https://registry.npmjs.org'],1);assert.equal(s['publish:https://registry.npmjs.org'],undefined);assert.equal(f.receipt().receipts.npm.status,'unknown');}finally{f.clean();}
 });
}

test('recovery observes a lagging channel once without retrying or rewriting latest', () => {
 const f=fixture();try {assert.throws(()=>f.run({RECOVERY:'true'}));const s=JSON.parse(readFileSync(join(f.root,'state.json')));assert.equal(s['tags:https://registry.npmjs.org'],2);const r=f.receipt().receipts.npm;assert.equal(r.status,'unknown');assert.equal(r.bytes_verified,true);assert.equal(r.publication_accepted,true);}finally{f.clean();}
});
