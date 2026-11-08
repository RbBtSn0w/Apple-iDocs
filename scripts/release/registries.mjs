import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export function registryState(registry, version, environment = process.env) {
  try {
    return JSON.parse(execFileSync('npm', ['view', `@rbbtsn0w/idocs@${version}`, 'dist.integrity', '--registry', registry, '--json'], { env: environment, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 }));
  } catch (error) {
    if (/\bE404\b/.test(String(error.stderr))) return null;
    throw new Error(`Cannot inspect registry ${registry}; publication stopped`);
  }
}

function readTags(registry, env) {
  try {
    const tags = JSON.parse(execFileSync('npm', ['view', '@rbbtsn0w/idocs', 'dist-tags', '--registry', registry, '--json'], {env, encoding: 'utf8', timeout: 60000}));
    if (!tags || typeof tags !== 'object' || Array.isArray(tags)) throw Error('Malformed registry tags');
    return tags;
  } catch (error) {
    if (/\bE404\b/.test(String(error.stderr))) return {};
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

function reconcileChannels(registry, plan, env, recoveryTag) {
  const tags = readTags(registry, env);
  const version = plan.next.version;
  if (!tags.latest || compareStable(tags.latest, version) < 0) {
    execFileSync('npm', ['dist-tag', 'add', `@rbbtsn0w/idocs@${version}`, 'latest', '--registry', registry], {env, stdio: 'inherit', timeout: 60000});
    const confirmed = readTags(registry, env).latest;
    if (!confirmed || compareStable(confirmed, version) < 0) throw Error('Stable registry channel not confirmed');
  }
  // Remove only this original candidate's own temporary label after its bytes and
  // the stable channel are verified. A different value is never deleted.
  if (recoveryTag) {
    const current = readTags(registry, env)[recoveryTag];
    if (current !== undefined && current !== version) throw Error('Recovery tag ownership conflict');
    if (current === version) execFileSync('npm', ['dist-tag', 'rm', '@rbbtsn0w/idocs', recoveryTag, '--registry', registry], {env, stdio: 'inherit', timeout: 60000});
    if (readTags(registry, env)[recoveryTag] !== undefined) throw Error('Recovery tag cleanup not confirmed');
  }
}

export async function publishRegistries(directory, plan, {recovery = false} = {}) {
  const archive = join(directory, 'package.tgz');
  const integrity = `sha512-${createHash('sha512').update(readFileSync(archive)).digest('base64')}`;
  // Ensure the native asset that the wrapper downloads is already available with these bytes.
  const remote = execFileSync('gh', ['api', `repos/RbBtSn0w/Apple-iDocs/releases/tags/${plan.next.gitTag}`, '--jq', '.assets[] | select(.name == "idocs-darwin-arm64.tar.gz") | .id'], { encoding: 'utf8', timeout: 30000 }).trim();
  if (!/^\d+$/.test(remote)) throw new Error('Native release asset is unavailable');
  const downloaded = execFileSync('gh', ['api', `repos/RbBtSn0w/Apple-iDocs/releases/assets/${remote}`, '-H', 'Accept: application/octet-stream'], { maxBuffer: 256 * 1024 * 1024, timeout: 60000 });
  const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
  if (sha256(downloaded) !== sha256(readFileSync(join(directory, 'idocs-darwin-arm64.tar.gz')))) throw new Error('Published native asset differs from verified archive');
  const receipt = { candidate: plan.candidate, version: plan.next.version, integrity, registries: {npm: 'not-run', github: 'not-run'}, receipts: {} };
  for (const [name, registry] of Object.entries({ npm: 'https://registry.npmjs.org', github: 'https://npm.pkg.github.com' })) {
    try {
      const env = { ...process.env, NPM_CONFIG_IGNORE_SCRIPTS: 'true' };
      const recoveryTag = recovery ? `idocs-recovery-${plan.next.version}-${plan.candidate.slice(0, 12)}` : null;
      const tags = readTags(registry, env);
      if (recoveryTag && tags[recoveryTag] !== undefined && tags[recoveryTag] !== plan.next.version) throw Error('Recovery tag ownership conflict');
      if (!recovery && tags.latest && compareStable(tags.latest, plan.next.version) > 0) throw Error('Normal publication would downgrade stable registry channel');
      const before = registryState(registry, plan.next.version, env);
      if (before !== null && before !== integrity) throw new Error(`${name} already contains different bytes`);
      if (before === null) {
        execFileSync('npm', ['publish', archive, '--registry', registry, '--tag', recoveryTag || 'latest', '--access', 'public', '--ignore-scripts', `--provenance=${name === 'npm'}`], { env, stdio: 'inherit', timeout: 120000 });
      }
      let after;
      for (let attempt = 0; attempt < 6; attempt++) {
        after = registryState(registry, plan.next.version, env);
        if (after !== null) break;
        await new Promise((resolve) => setTimeout(resolve, 3000));
      }
      if (after !== integrity) throw new Error(`${name} publication integrity not confirmed`);
      reconcileChannels(registry, plan, env, recoveryTag);
      receipt.registries[name] = 'verified';
      receipt.receipts[name] = {status: 'completed', candidate_sha: plan.candidate, version: plan.next.version,
        integrity, observed_at: new Date().toISOString(), remote_id: `@rbbtsn0w/idocs@${plan.next.version}`,
        url: name === 'npm' ? `https://www.npmjs.com/package/@rbbtsn0w/idocs/v/${plan.next.version}` : `https://github.com/${process.env.GITHUB_REPOSITORY || 'RbBtSn0w/Apple-iDocs'}/pkgs/npm/idocs`};
      writeFileSync(join(directory, 'registries.json'), JSON.stringify(receipt, null, 2) + '\n');
    } catch (error) {
      receipt.registries[name] = 'unknown';
      writeFileSync(join(directory, 'registries.json'), JSON.stringify(receipt, null, 2) + '\n');
      throw error;
    }
  }
}
