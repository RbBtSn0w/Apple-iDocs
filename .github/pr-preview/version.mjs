import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseNpmView } from '../release-train/npm-view.mjs';

export const packageName = '@rbbtsn0w/idocs';
export const npmRegistry = 'https://registry.npmjs.org';
export const githubRegistry = 'https://npm.pkg.github.com';
export const versionCore = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
export const positiveId = /^[1-9]\d*$/;
export const fullSha = /^[0-9a-f]{40}$/;

export function stableCore(version) {
  if (typeof version !== 'string' || !versionCore.test(version)) throw new Error('Expected a stable SemVer');
  return version.split('.').map(BigInt);
}

function compare(a, b) {
  const difference = a.findIndex((value, index) => value !== b[index]);
  return difference === -1 ? 0 : a[difference] > b[difference] ? 1 : -1;
}

export function previewVersion(manifest, latest, pr, head) {
  if (!positiveId.test(pr) || !fullSha.test(head)) throw new Error('Invalid PR or full head SHA');
  const base = stableCore(manifest);
  const minimum = stableCore(latest ?? manifest);
  minimum[2] += 1n;
  const core = compare(base, minimum) < 0 ? minimum : base;
  return `${core.join('.')}-dev.pr${pr}.g${head}`;
}

export function requireNewerPreview(version, baseline) {
  const core = stableCore(version.split('-', 1)[0]);
  if (compare(core, stableCore(baseline)) <= 0) {
    throw new Error(`Preview ${version} must be newer than stable ${baseline}. Rebuild the preview.`);
  }
}

export function npmView(registry, spec, field, { cwd, env = process.env, timeout = 12000, config } = {}) {
  return spawnSync('npm', ['view', spec, field, '--json', '--prefer-online', '--registry', registry,
    '--fetch-retries=0', '--fetch-timeout=10000', ...(config ?? [])], { cwd, env, encoding: 'utf8', timeout });
}

export function readTags(registry, options) {
  const result = npmView(registry, packageName, 'dist-tags', options);
  if (result.error || result.status !== 0) throw new Error(`Could not read dist-tags from ${registry}`);
  const tags = parseNpmView(result.stdout);
  if (!tags || typeof tags !== 'object' || Array.isArray(tags) || Object.values(tags).some(tag => typeof tag !== 'string')) {
    throw new Error('Invalid npm dist-tags');
  }
  return tags;
}

export function readStableLatest() {
  const cwd = mkdtempSync(join(tmpdir(), 'idocs-preview-latest-'));
  try {
    const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !/^(npm_config_|npm_token$|node_auth_token$)/i.test(key)));
    const opts = { cwd, env, config: ['--userconfig', join(cwd, 'user.npmrc'), '--globalconfig', join(cwd, 'global.npmrc'), '--cache', join(cwd, 'cache')] };
    const { latest } = readTags(npmRegistry, opts);
    stableCore(latest);
    return latest;
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
}
