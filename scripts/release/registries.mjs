import {createNpmObservationBudget, parseNpmView} from '../../.github/release-train/npm-view.mjs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { validateLatestVersion } from '../../.github/release-train/npm-channel.mjs';

function missingPackage(error) {
  if (error.signal || error.code === 'ETIMEDOUT') return false;
  try { return parseNpmView(String(error.stdout)).error?.code === 'E404'; }
  catch { return false; }
}

export function registryState(registry, version, environment = process.env, timeoutMs = 60000) {
  try {
    const integrity = parseNpmView(execFileSync('npm', ['view', `@rbbtsn0w/idocs@${version}`, 'dist.integrity', '--registry', registry, '--json'], { env: environment, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: Math.min(60000, timeoutMs) }));
    if (typeof integrity !== 'string' || !integrity) throw Error('Malformed registry integrity');
    return integrity;
  } catch (error) {
    if (missingPackage(error)) return null;
    throw new Error(`Cannot inspect registry ${registry}; publication stopped`);
  }
}

function readTags(registry, env, timeoutMs) {
  try {
    const tags = parseNpmView(execFileSync('npm', ['view', '@rbbtsn0w/idocs', 'dist-tags', '--registry', registry, '--json'], {env, encoding: 'utf8', timeout: Math.min(60000, timeoutMs)}));
    if (!tags || typeof tags !== 'object' || Array.isArray(tags) || Object.values(tags).some(value => typeof value !== 'string')) throw Error('Malformed registry tags');
    return tags;
  } catch (error) {
    if (missingPackage(error)) return {};
    throw new Error('Cannot verify registry channel; refusing tag changes');
  }
}

function compareStable(left, right) {
  const stable = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
  if (!stable.test(left) || !stable.test(right)) throw Error('Unverifiable stable registry version');
  const a = left.split('.').map(BigInt), b = right.split('.').map(BigInt);
  const index = a.findIndex((value, index) => value !== b[index]);
  return index < 0 ? 0 : a[index] > b[index] ? 1 : -1;
}

function observeChannel(registry, plan, env, timeoutMs) {
  const latest = readTags(registry, env, timeoutMs).latest;
  // Missing or older stable channels may still be propagating. Invalid values
  // cannot establish a legal channel and must fail without retrying.
  if (latest === undefined) return null;
  if (compareStable(latest, plan.next.version) < 0) return null;
  validateLatestVersion({version: plan.next.version}, latest);
  return {latest_version: latest, channel_observed_at: new Date().toISOString()};
}

export async function publishRegistries(directory, plan, {recovery = false, observationBudget = createNpmObservationBudget()} = {}) {
  const archive = join(directory, 'package.tgz');
  const integrity = `sha512-${createHash('sha512').update(readFileSync(archive)).digest('base64')}`;
  // Ensure the native asset that the wrapper downloads is already available with these bytes.
  const remote = execFileSync('gh', ['api', `repos/RbBtSn0w/Apple-iDocs/releases/tags/${plan.next.gitTag}`, '--jq', '.assets[] | select(.name == "idocs-darwin-arm64.tar.gz") | .id'], { encoding: 'utf8', timeout: Math.min(30000, observationBudget.assertRemaining()) }).trim();
  if (!/^\d+$/.test(remote)) throw new Error('Native release asset is unavailable');
  const downloaded = execFileSync('gh', ['api', `repos/RbBtSn0w/Apple-iDocs/releases/assets/${remote}`, '-H', 'Accept: application/octet-stream'], { maxBuffer: 256 * 1024 * 1024, timeout: Math.min(60000, observationBudget.assertRemaining()) });
  const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
  if (sha256(downloaded) !== sha256(readFileSync(join(directory, 'idocs-darwin-arm64.tar.gz')))) throw new Error('Published native asset differs from verified archive');
  const receipt = { candidate: plan.candidate, version: plan.next.version, integrity, registries: {npm: 'not-run', github: 'not-run'}, receipts: {} };
  const persist = () => writeFileSync(join(directory, 'registries.json'), JSON.stringify(receipt, null, 2) + '\n');
  for (const [name, registry] of Object.entries({ npm: 'https://registry.npmjs.org', github: 'https://npm.pkg.github.com' })) {
    observationBudget.assertRemaining();
    receipt.receipts[name] = {status: 'unknown', candidate_sha: plan.candidate, version: plan.next.version,
      integrity, observed_at: new Date().toISOString(), remote_id: `@rbbtsn0w/idocs@${plan.next.version}`};
    persist();
    try {
      const env = { ...process.env, NPM_CONFIG_IGNORE_SCRIPTS: 'true' };
      const recoveryTag = recovery ? `idocs-recovery-${plan.next.version}-${plan.candidate.slice(0, 12)}` : null;
      const tags = readTags(registry, env, observationBudget.assertRemaining());
      if (recoveryTag && tags[recoveryTag] !== undefined && tags[recoveryTag] !== plan.next.version) throw Error('Recovery tag ownership conflict');
      if (tags.latest !== undefined) compareStable(tags.latest, plan.next.version);
      if (!recovery && tags.latest !== undefined && compareStable(tags.latest, plan.next.version) > 0) throw Error('Normal publication would downgrade stable registry channel');
      const before = registryState(registry, plan.next.version, env, observationBudget.assertRemaining());
      if (before !== null && before !== integrity) throw new Error(`${name} already contains different bytes`);
      if (before === null) {
        const timeoutMs = Math.min(120000, observationBudget.assertRemaining());
        receipt.receipts[name].request_started_at = new Date().toISOString();
        persist();
        execFileSync('npm', ['publish', archive, '--registry', registry, '--tag', recoveryTag || 'latest', '--access', 'public', '--ignore-scripts', `--provenance=${name === 'npm'}`], { env, stdio: 'inherit', timeout: timeoutMs });
        Object.assign(receipt.receipts[name], {publication_accepted: true, accepted_at: new Date().toISOString()});
        persist();
      }
      await observationBudget.wait((timeoutMs) => {
        const after = registryState(registry, plan.next.version, env, timeoutMs);
        if (after !== null && after !== integrity) throw new Error(`${name} publication integrity not confirmed`);
        return after;
      });
      Object.assign(receipt.receipts[name], {bytes_verified: true, channel_blocked: true});
      persist();
      const channel = recovery
        ? observeChannel(registry, plan, env, observationBudget.assertRemaining())
        : await observationBudget.wait((timeoutMs) => observeChannel(registry, plan, env, timeoutMs));
      if (channel === null) throw Error('Recovery channel availability is not confirmed; preserve the original receipt and artifact');
      receipt.registries[name] = 'verified';
      receipt.receipts[name] = {...receipt.receipts[name], status: 'completed', channel_blocked: false, candidate_sha: plan.candidate, version: plan.next.version,
        integrity, ...channel, ...(recoveryTag ? {recovery_tag: recoveryTag} : {}), observed_at: new Date().toISOString(), remote_id: `@rbbtsn0w/idocs@${plan.next.version}`,
        url: name === 'npm' ? `https://www.npmjs.com/package/@rbbtsn0w/idocs/v/${plan.next.version}` : `https://github.com/${process.env.GITHUB_REPOSITORY || 'RbBtSn0w/Apple-iDocs'}/pkgs/npm/idocs`};
      persist();
    } catch (error) {
      receipt.registries[name] = 'unknown';
      receipt.receipts[name].reason = error.message;
      persist();
      throw error;
    }
  }
}
