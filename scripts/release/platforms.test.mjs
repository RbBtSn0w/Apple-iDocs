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
