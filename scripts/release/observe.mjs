// Remote receipts, never job success, establish channel completion.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {writeResult} from '../../.github/release-train/release-result.mjs';
import {validateLatestVersion} from '../../.github/release-train/npm-channel.mjs';
import {validateOriginalPlan} from '../../.github/release-train/release-entrypoint.mjs';
const read = name => {try {return JSON.parse(readFileSync(name));} catch {return null;}};
const needs = JSON.parse(process.env.RELEASE_NEEDS);
const mapping = JSON.parse(process.env.RELEASE_TARGETS);
const config = JSON.parse(readFileSync(new URL('../../.github/release-train.json', import.meta.url)));
const original = process.env.RELEASE_OPERATION === 'recover';
const source = original ? needs['recovery-input'] : needs.verify;
const outputs = source?.outputs ?? {};
const plan = read('result-input/plan.json');
validateOriginalPlan(plan);
const intended = plan?.pipeline?.pipeline?.goals?.map(goal=>goal.id)??config.intended_targets;
const candidate = outputs.source_sha || plan?.candidate || process.env.GITHUB_SHA;
const version = outputs.version || plan?.next?.version || null;
const active = process.env.RELEASE_ENABLED === 'true';
const attempted = Object.values(mapping).some(job => ['success','failure','cancelled'].includes(needs[job]?.result));
const targets = Object.fromEntries(intended.map(name => [name, {status: attempted ? 'unknown' : 'not-run', reason: attempted ? 'No matching remote receipt' : active ? 'Publication not required or validation did not pass' : 'Publication disabled'}]));
const matches = receipt => receipt?.candidate_sha === candidate && receipt.version === version && Number.isFinite(Date.parse(receipt.observed_at)) && (receipt.remote_id || receipt.url);
const github = read('publication-input/github-observation.json');
for (const name of ['stable_tag','github']) if (matches(github?.targets?.[name])) targets[name] = github.targets[name];
const registries = read('publication-input/registries.json');
let integrity;
try {integrity = 'sha512-' + createHash('sha512').update(readFileSync('publication-input/package.tgz')).digest('base64');} catch { /* Original payload is required to establish registry bytes. */ }
if (registries?.candidate === candidate && registries.version === version && registries.integrity === integrity && integrity) {
  for (const [registry, target] of [['npm','npm'],['github','github-packages']]) {
    const receipt = registries.receipts?.[registry];
    if (matches(receipt) && receipt.integrity === integrity) {
      if(receipt.channel_blocked===true)targets[target]={...receipt,status:'unknown'};
      else try {
        validateLatestVersion({version},receipt.latest_version);
        if(!Number.isFinite(Date.parse(receipt.channel_observed_at)))throw Error('Channel observation time is unavailable');
        if(registries.registries[registry]==='verified')targets[target]=receipt;
      } catch {targets[target]={...receipt,status:'unknown',bytes_verified:true,channel_blocked:true,reason:'Registry channel receipt is not confirmed'};}
    }
  }
}
const homebrew = read('publication-input/homebrew-receipt.json');
if (matches(homebrew)) targets.homebrew = homebrew;

const failed = Object.entries(needs).find(([, job]) => ['failure','cancelled'].includes(job.result));
const downloadFailure = Object.values(JSON.parse(process.env.REPORT_DOWNLOADS || '{}')).some(outcome => outcome === 'failure');
let recovery=read('publication-input/recovery-availability.json');
if(Object.values(targets).some(target=>target.channel_blocked)){
  recovery={...recovery,available:false,blocked_reason:'The latest registry channel is not confirmed; recovery preserves shared channels and cannot repair this gap automatically.'};
  delete recovery.command;
}
writeResult('release-result.json', {
  schema_version: 2, candidate_sha: candidate, baseline_tag: plan?.baseline?.gitTag ?? null, version,
  analysis: plan?.candidate === candidate ? (version ? 'release' : 'no-release') : 'failed',
  enabled: active, verification: source?.result === 'success' ? 'passed' : source?.result === 'failure' ? 'failed' : 'not-run',
  intended_targets: intended, targets, concluded: true,
  artifacts: outputs.artifact_id ? [{id: outputs.artifact_id}] : [],
  failure_stage: downloadFailure ? 'report-input' : failed?.[0] ?? null,
  recovery,
  errors: [...(failed ? [`${failed[0]} ${failed[1].result}; inspect its named step and channel evidence.`] : []), ...(downloadFailure ? ['An immutable report input could not be downloaded; completion is not confirmed.'] : [])],
}, {config,plan});
