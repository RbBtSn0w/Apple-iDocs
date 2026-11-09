import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import test from 'node:test';

test('real recovery phases preserve accepted public evidence, publish independent GitHub target and gate finalization', () => {
 const root=mkdtempSync(join(tmpdir(),'idocs-recovery-phases-')),bin=join(root,'bin');mkdirSync(bin);
 const candidate='a'.repeat(40),plan={candidate,next:{version:'1.0.1',gitTag:'v1.0.1'}};
 const integrity='sha512-'+createHash('sha512').update('wrapper').digest('base64');
 const files={'plan.json':JSON.stringify(plan),'package.tgz':'wrapper','idocs-darwin-arm64.tar.gz':'native','idocs-darwin-arm64.sha256':'sealed'};
 for(const [name,bytes]of Object.entries(files))writeFileSync(join(root,name),bytes);
 writeFileSync(join(root,'artifact.json'),JSON.stringify({candidate,files:Object.fromEntries(Object.entries(files).map(([name,bytes])=>[name,createHash('sha256').update(bytes).digest('hex')]))}));
 const facts={request_started_at:'2026-11-09T01:00:00Z',publication_accepted:true,accepted_at:'2026-11-09T01:01:00Z'};
 const metadata={candidate_sha:candidate,version:'1.0.1',integrity};
 writeFileSync(join(root,'registries.json'),JSON.stringify({receipts:{npm:{...metadata,...facts,status:'unknown'},github:{...metadata,status:'not-run'}}}));
 writeFileSync(join(bin,'gh'),`#!${process.execPath}
const query=process.argv.find(a=>a.includes('/actions/artifacts?name='));
if(query){const name=query.split('name=')[1].split('&')[0];console.log(JSON.stringify([{artifacts:name.endsWith('-github-packages')?[{id:78,name,expired:false,workflow_run:{id:56}}]:[]}]));}else process.stdout.write(process.argv.includes('--jq')?'42':'native');
`,{mode:0o755});
 writeFileSync(join(bin,'npm'),`#!${process.execPath}
const fs=require('fs'),p=require('path'),a=process.argv.slice(2),file=p.join(process.env.FIXTURE,'remote.json'),s=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{};
const github=a[a.indexOf('--registry')+1].includes('github');
if(a[0]==='publish'){if(!github)process.exit(42);s.github=true;s.uploads=(s.uploads||0)+1;fs.writeFileSync(file,JSON.stringify(s));}
else if(a[2]==='dist-tags')console.log(JSON.stringify({latest:github||process.env.PUBLIC_READY==='true'?'1.0.1':'0.9.0'}));
else if(!github||s.github)console.log(JSON.stringify(process.env.INTEGRITY));
else{console.log(JSON.stringify({error:{code:'E404'}}));process.exit(1);}
`,{mode:0o755});
 const run=(phase,target,extra={})=>execFileSync(process.execPath,[resolve('scripts/release/release.mjs'),'recover',root],{env:{...process.env,PATH:bin+':'+process.env.PATH,FIXTURE:root,INTEGRITY:integrity,GITHUB_REF:'refs/heads/main',GITHUB_EVENT_NAME:'workflow_dispatch',RELEASE_ENABLED:'true',RECOVERY_CANDIDATE:candidate,GITHUB_REPOSITORY:'RbBtSn0w/Apple-iDocs',GITHUB_RUN_ID:'56',SOURCE_RUN_ID:'12',ARTIFACT_ID:'34',RECOVERY_PHASE:phase,RECOVERY_TARGET:target,RECOVERY_OBSERVATION_DEADLINE_NS:(process.hrtime.bigint()+60000000000n).toString(),...extra},encoding:'utf8',stdio:'pipe',timeout:10000});
 try {
  const preflight=join(root,'preflight');run('preflight','npm',{GITHUB_OUTPUT:preflight});
  assert.equal(readFileSync(preflight,'utf8'),'request_needed=false\n');
  run('registry','npm');
  const before=JSON.parse(readFileSync(join(root,'registries.json')));
  assert.equal(before.receipts.npm.bytes_verified,true);
  assert.equal(before.receipts.github.status,'not-run');
  run('registry','github-packages',{RECOVERY_INTENT_ARTIFACT_ID:'78'});
  assert.throws(()=>run('finalize'),/remains incomplete: npm/);
  run('registry','npm',{PUBLIC_READY:'true'});
  const output=join(root,'output');run('finalize',undefined,{GITHUB_OUTPUT:output});
  assert.match(readFileSync(output,'utf8'),/released=true/);
  const receipt=JSON.parse(readFileSync(join(root,'registries.json')));
  for(const [key,value]of Object.entries(facts))assert.equal(receipt.receipts.npm[key],value);
  assert.equal(JSON.parse(readFileSync(join(root,'remote.json'))).uploads,1);
 } finally {rmSync(root,{recursive:true,force:true});}
});
