import { appendFileSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createNpmObservationBudget, parseNpmIntegrity } from '../release-train/npm-view.mjs';
import { tarballName, verifyArtifact } from './artifact.mjs';
import { isCurrent } from './github.mjs';
import { githubRegistry, npmRegistry, npmView, packageName, readStableLatest, readTags, requireNewerPreview } from './version.mjs';
import { execPreview, withPreviewTrace } from './telemetry.mjs';

export async function publishPreview({ receipt, readExact, readNext, readLatest, checkHead, send,
  newBudget = () => createNpmObservationBudget({ timeoutMs: 120000, intervalMs: 5000 }) }) {
  const { version, baseline } = receipt;
  if (!baseline) throw new Error('Preview has no verified npm latest baseline');
  requireNewerPreview(version, baseline);
  let available = readExact(12000) === true;
  const alreadyAvailable = available;
  let request = 'existing';
  if (!available) {
    requireNewerPreview(version, readLatest());
    checkHead();
    try {
      send();
      request = 'accepted';
    } catch {
      // The registry can accept a request before returning a failure or timeout.
      request = 'unconfirmed';
    }
  }
  const budget = newBudget();
  try {
    return await budget.wait(timeout => {
      available ||= readExact(timeout) === true;
      if (!available) return null;
      let next;
      try {
        next = readNext(budget.assertRemaining());
      } catch {
        return { available, next: false, request, observation: 'tag-unverified' };
      }
      if (next || alreadyAvailable) return { available, next, request, observation: next ? 'verified' : 'tag-unverified' };
      return null;
    });
  } catch (error) {
    if (error.code !== 'NPM_AVAILABILITY_PENDING') throw error;
    return { available, next: false, request, observation: available ? 'tag-unverified' : 'pending' };
  }
}

async function observeTarget(target, receipt, archive) {
  const env = { ...process.env };
  const mirror = target === 'github-packages';
  const registry = mirror ? githubRegistry : npmRegistry;
  const cwd = mkdtempSync(join(tmpdir(), 'idocs-preview-registry-'));
  const config = join(cwd, 'npmrc');
  delete env.NPM_TOKEN;
  delete env.NODE_AUTH_TOKEN;
  if (mirror) {
    if (!env.GH_TOKEN) throw new Error('GitHub Packages requires the job token');
    env.NODE_AUTH_TOKEN = env.GH_TOKEN;
    writeFileSync(config, '//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}\n', { mode: 0o600 });
  }
  const options = { cwd, env, config: ['--userconfig', config, '--globalconfig', join(cwd, 'global.npmrc'), '--cache', join(cwd, 'cache')] };
  try {
    const result = await publishPreview({
      receipt,
      readExact: timeout => parseNpmIntegrity(npmView(registry, `${packageName}@${receipt.version}`, 'dist.integrity',
        { ...options, timeout: Math.min(timeout, 12000) }), receipt.integrity, target),
      readNext: timeout => readTags(registry, { ...options, timeout: Math.min(timeout, 12000) }).next === receipt.version,
      readLatest: readStableLatest,
      checkHead: () => {
        const { GITHUB_REPOSITORY: repository } = env;
        const current = JSON.parse(execPreview('gh', ['api', `repos/${repository}/pulls/${receipt.pr}`], { env, encoding: 'utf8', timeout: 12000 }));
        if (!isCurrent(current, receipt.head, repository)) throw new Error('PR head changed before registry publication');
      },
      send: () => execPreview('npm', ['publish', archive, '--ignore-scripts', '--access', 'public', '--tag', 'next',
        '--registry', registry, `--provenance=${!mirror}`, ...options.config], { cwd, env, stdio: 'inherit', timeout: 120000 }),
    });
    return result;
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
}

async function main(target, input) {
  if (!['npmjs', 'github-packages'].includes(target)) throw new Error('Invalid preview registry');
  const directory = resolve(input);
  const receipt = verifyArtifact(directory, process.env);
  const result = await observeTarget(target, receipt, join(directory, tarballName));
  appendFileSync(process.env.GITHUB_OUTPUT, `status=${JSON.stringify(result)}\n`);
  if (!result.available) throw new Error(`Could not verify ${target} preview bytes (${result.request}, ${result.observation})`);
}

if (import.meta.main) await withPreviewTrace('idocs-pr-preview-publish', () => main(...process.argv.slice(2)));
