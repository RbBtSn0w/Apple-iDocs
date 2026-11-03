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

export async function publishRegistries(directory, plan) {
  const archive = join(directory, 'package.tgz');
  const integrity = `sha512-${createHash('sha512').update(readFileSync(archive)).digest('base64')}`;
  // Ensure the native asset that the wrapper downloads is already available with these bytes.
  const remote = execFileSync('gh', ['api', `repos/RbBtSn0w/Apple-iDocs/releases/tags/${plan.next.gitTag}`, '--jq', '.assets[] | select(.name == "idocs-darwin-arm64.tar.gz") | .id'], { encoding: 'utf8', timeout: 30000 }).trim();
  if (!/^\d+$/.test(remote)) throw new Error('Native release asset is unavailable');
  const downloaded = execFileSync('gh', ['api', `repos/RbBtSn0w/Apple-iDocs/releases/assets/${remote}`, '-H', 'Accept: application/octet-stream'], { maxBuffer: 256 * 1024 * 1024, timeout: 60000 });
  const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
  if (sha256(downloaded) !== sha256(readFileSync(join(directory, 'idocs-darwin-arm64.tar.gz')))) throw new Error('Published native asset differs from verified archive');
  const receipt = { candidate: plan.candidate, version: plan.next.version, integrity, registries: {} };
  for (const [name, registry] of Object.entries({ npm: 'https://registry.npmjs.org', github: 'https://npm.pkg.github.com' })) {
    const env = { ...process.env, NPM_CONFIG_IGNORE_SCRIPTS: 'true' };
    const before = registryState(registry, plan.next.version, env);
    if (before !== null && before !== integrity) throw new Error(`${name} already contains different bytes`);
    if (before === null) {
      execFileSync('npm', ['publish', archive, '--registry', registry, '--tag', 'latest', '--access', 'public', '--ignore-scripts', `--provenance=${name === 'npm'}`], { env, stdio: 'inherit', timeout: 120000 });
    }
    let after;
    for (let attempt = 0; attempt < 6; attempt++) {
      after = registryState(registry, plan.next.version, env);
      if (after !== null) break;
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
    if (after !== integrity) throw new Error(`${name} publication integrity not confirmed`);
    receipt.registries[name] = 'verified';
    writeFileSync(join(directory, 'registries.json'), JSON.stringify(receipt, null, 2) + '\n');
  }
}
