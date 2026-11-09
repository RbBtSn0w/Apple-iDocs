import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';
import {observePlatforms} from './observe-platforms.mjs';
import {analyze} from './train-adapter.mjs';
test('remote native asset bytes are required even when tag and notes match', () => {
  const cwd = mkdtempSync(join(tmpdir(), 'native-readback-'));
  try {
    const candidate = 'a'.repeat(40), bytes = Buffer.from('original archive');
    mkdirSync(join(cwd,'result-input')); mkdirSync(join(cwd,'publication-input'));
    writeFileSync(join(cwd,'result-input/plan.json'),JSON.stringify({candidate,next:{version:'1.2.3',gitTag:'v1.2.3'},notes:'Original notes'}));
    writeFileSync(join(cwd,'publication-input/artifact.json'),JSON.stringify({candidate,files:{'native.tar.gz':createHash('sha256').update(bytes).digest('hex')}}));
    const read = path => path.includes('/git/ref/') ? {ref:'refs/tags/v1.2.3',object:{type:'commit',sha:candidate}} : {id:42,tag_name:'v1.2.3',body:'Original notes',draft:false,prerelease:false,assets:[{name:'native.tar.gz',id:99}]};
    const options = {cwd,env:{RELEASE_ENABLED:'true',GITHUB_REPOSITORY:'example/idocs'},read};
    assert.equal(observePlatforms({...options,download:()=>bytes}).observation.targets.github.status,'completed');
    assert.equal(observePlatforms({...options,download:()=>Buffer.from('changed')}).observation.targets.github.status,'unknown');
    assert.equal(observePlatforms({...options,download:()=>bytes}).recovery.available,false);
  } finally {rmSync(cwd,{recursive:true,force:true});}
});
test('analyzing an all-job retry stops before product tools or version analysis', () => {
  assert.throws(()=>analyze({cwd:'/nonexistent',env:{GITHUB_RUN_ATTEMPT:'2',GITHUB_REPOSITORY:'example/idocs',GITHUB_RUN_ID:'123'},args:[]}),/recover the original release or start a new main run/);
});
test('first-failure recovery blocks known conflicts while retaining missing/draft repair', () => {
  const cwd=mkdtempSync(join(tmpdir(),'idocs-recovery-observation-'));
  try {
    const candidate='a'.repeat(40),bytes=Buffer.from('original'),repository='example/idocs';
    mkdirSync(join(cwd,'result-input'));mkdirSync(join(cwd,'publication-input'));
    writeFileSync(join(cwd,'result-input/plan.json'),JSON.stringify({candidate,next:{version:'1.2.3',gitTag:'v1.2.3'},notes:'Original notes'}));
    writeFileSync(join(cwd,'publication-input/artifact.json'),JSON.stringify({candidate,files:{'native.tar.gz':createHash('sha256').update(bytes).digest('hex')}}));
    for(const change of ['notes','bytes','duplicate','denied','missing','draft']) {
      const read=path=>{
        if(path.includes('/git/ref/'))return {ref:'refs/tags/v1.2.3',object:{type:'commit',sha:candidate}};
        if(path.includes('/releases/tags/')){if(change==='denied')throw Error('Permission denied');return {id:42,tag_name:'v1.2.3',body:change==='notes'?'Conflicting notes':'Original notes',draft:change==='draft',prerelease:false,assets:change==='missing'?[]:change==='duplicate'?[{name:'native.tar.gz',id:99},{name:'native.tar.gz',id:100}]:[{name:'native.tar.gz',id:99}]};}
        if(path.includes('/actions/runs/'))return {id:11,head_sha:candidate,head_branch:'main',event:'schedule',status:'in_progress',run_attempt:1,path:'.github/workflows/release.yml',repository:{full_name:repository}};
        if(path.includes('/actions/artifacts/'))return {id:22,name:`idocs-publication-${candidate}-1`,expired:false,workflow_run:{id:11,head_sha:candidate},digest:'sha256:'+'f'.repeat(64),expires_at:'2099-01-01T00:00:00Z'};
        throw Error(path);
      };
      const result=observePlatforms({cwd,env:{RELEASE_ENABLED:'true',GITHUB_REPOSITORY:repository,GITHUB_RUN_ID:'11',ORIGINAL_RUN_ID:'11',RECOVERY_ARTIFACT_ID:'22'},read,download:()=>change==='bytes'?Buffer.from('conflict'):bytes});
      assert.equal(result.recovery.available,['missing','draft'].includes(change),change);
      if(!result.recovery.available)assert.equal(result.recovery.command,undefined);
    }
  } finally {rmSync(cwd,{recursive:true,force:true});}
});
