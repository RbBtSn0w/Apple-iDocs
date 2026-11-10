import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import * as adapter from './train-adapter.mjs';
import {captureAnalysis} from '../../.github/release-train/release-entrypoint.mjs';
import {createPipelinePlan} from '../../.github/release-train/pipeline-contract.mjs';
import {reportExitCode} from '../../.github/release-train/release-result.mjs';
import {checkReleaseArtifacts} from './release.mjs';
const candidate='a'.repeat(40);
const identity={candidate_sha:candidate,version:'1.2.3',tag:'v1.2.3',notes:'Original notes',baseline_tag:'v1.2.2'};
const plan=()=>({candidate,next:{version:identity.version,gitTag:identity.tag},notes:identity.notes,baseline:{gitTag:identity.baseline_tag}});
const config=()=>JSON.parse(readFileSync(new URL('../../.github/release-train.json',import.meta.url)));
function fixture(fn){const cwd=mkdtempSync(join(tmpdir(),'idocs-pipeline-'));try{fn(cwd);}finally{rmSync(cwd,{recursive:true,force:true});}}
test('custom adapter exposes engine identity and captures original envelope without a second version decision',()=>fixture(cwd=>{
  assert.equal(adapter.pipelineProtocolVersion,1);
  assert.equal(adapter.analysisFile({args:[]}), 'release-input/plan.json');
  assert.equal(adapter.analysisFile({args:['--directory','sealed']}), 'sealed/plan.json');
  assert.deepEqual(adapter.planIdentity(plan()),identity);
  mkdirSync(join(cwd,'sealed'));writeFileSync(join(cwd,'sealed/plan.json'),JSON.stringify(plan()));
  captureAnalysis(adapter,{cwd,args:['--directory','sealed'],config:config(),env:{GITHUB_REPOSITORY:'example/idocs',GITHUB_EVENT_NAME:'workflow_dispatch'}});
  const captured=JSON.parse(readFileSync(join(cwd,'sealed/plan.json')));
  assert.deepEqual(captured.next,plan().next);assert.equal(captured.pipeline.identity.tag,identity.tag);
  assert.equal(captured.pipeline.identity.notes,identity.notes);
}));
test('present invalid original pipeline identity is rejected before artifact or registry consumption',()=>fixture(cwd=>{
  const original=createPipelinePlan({config:config(),identity:{...identity,repository:'example/idocs'}});
  const changed={...plan(),notes:'Changed notes',pipeline:original};
  assert.throws(()=>checkReleaseArtifacts(cwd,changed),/identity/);
}));
test('custom report returns parsed original goals and shared exit policy after configuration advances',()=>fixture(cwd=>{
  const original=config();const stage=structuredClone(original.pipeline.stages[0]);stage.id='original-only';
  original.pipeline.stages.push(stage);original.intended_targets.push('original-only');original.pipeline.goals.push({id:'original-only',stages:['original-only'],asynchronous:false,recovery:'unsupported'});
  mkdirSync(join(cwd,'result-input'));
  writeFileSync(join(cwd,'result-input/plan.json'),JSON.stringify({...plan(),pipeline:createPipelinePlan({config:original,identity:{...identity,repository:'example/idocs'}})}));
  const env={...process.env,RELEASE_ENABLED:'true',GITHUB_SHA:candidate,RELEASE_TARGETS:'{}',RELEASE_NEEDS:JSON.stringify({verify:{result:'success',outputs:{source_sha:candidate,version:identity.version}}})};
  const result=adapter.report({cwd,env});
  assert.ok(result.intended_targets.includes('original-only'));
  assert.equal(result.pipeline.source,'original-plan');assert.equal(reportExitCode(result),1);
}));
test('report rejects engine notes that differ from the immutable original envelope',()=>fixture(cwd=>{
  mkdirSync(join(cwd,'result-input'));
  const original=createPipelinePlan({config:config(),identity:{...identity,repository:'example/idocs'}});
  writeFileSync(join(cwd,'result-input/plan.json'),JSON.stringify({...plan(),notes:'Changed notes',pipeline:original}));
  const env={...process.env,RELEASE_ENABLED:'true',GITHUB_SHA:candidate,RELEASE_TARGETS:'{}',RELEASE_NEEDS:JSON.stringify({verify:{result:'success',outputs:{source_sha:candidate,version:identity.version}}})};
  assert.throws(()=>adapter.report({cwd,env}),/identity|Command failed/);
}));
