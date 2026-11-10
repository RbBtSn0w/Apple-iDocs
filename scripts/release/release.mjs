import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { lstatSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import semanticRelease from 'semantic-release';
import { analyzeCommits } from '../../.github/release-train/release-commit-analyzer.mjs';
import { generateNotes } from '../../.github/release-train/release-notes-generator.mjs';
import { analyzeCommits as validateSemantics } from '../../.github/release-train/commit-semantics.mjs';
import configuration from './config.mjs';
import {startRecoveryObservationBudget, recoveryObservationBudget} from '../../.github/release-train/npm-view.mjs';
import {assertNpmReceiptConfirmed} from '../../.github/release-train/npm-channel.mjs';
import {validateOriginalPlan} from '../../.github/release-train/release-entrypoint.mjs';

const here = dirname(fileURLToPath(import.meta.url));
export const root = resolve(here, '../..');
export const git = (cwd, ...args) => execFileSync('git', ['-c', 'core.fsmonitor=', '-C', cwd, ...args], { encoding: 'utf8', timeout: 30000 }).trim();
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
const configurationDigest = () => digest(Buffer.concat(['scripts/release/config.mjs', 'scripts/release/release.mjs', '.github/release-train/commit-semantics.mjs', '.github/release-train/release-commit-analyzer.mjs', '.github/release-train/release-notes-generator.mjs', 'scripts/release/package-lock.json'].map(name => readFileSync(join(root, name)))));
const baseline = ({ lastRelease = {} }) => ({ gitTag: lastRelease.gitTag ?? null, version: lastRelease.version ?? null, gitHead: lastRelease.gitHead ?? null });
const next = ({ nextRelease }) => nextRelease ? ({ version: nextRelease.version, gitTag: nextRelease.gitTag, channel: nextRelease.channel ?? null }) : null;

export function checkEntrypoint(ref, event) {
  if (ref !== 'refs/heads/main' || !['schedule', 'workflow_dispatch'].includes(event)) throw new Error('Release requires main and schedule/manual');
}

export function checkPlan(expected, actual) {
  for (const key of ['candidate', 'baseline', 'next', 'configuration', 'notes']) {
    if (!isDeepStrictEqual(expected[key], actual[key])) throw new Error(`Release plan changed: ${key}`);
  }
}

export function inspectArtifact(directory, plan, files) {
  validateOriginalPlan(plan);
  const receipt = files ? { candidate: plan.candidate, files: {} } : JSON.parse(readFileSync(join(directory, 'artifact.json')));
  if (receipt.candidate !== plan.candidate) throw new Error('Artifact candidate mismatch');
  const names = files ?? Object.keys(receipt.files);
  if (!names.length) throw new Error('Missing release artifacts');
  for (const name of names) {
    if (!/^[A-Za-z0-9_.-]+$/.test(name)) throw new Error('Unsafe artifact path');
    const path = join(directory, name);
    if (!lstatSync(path).isFile()) throw new Error('Artifact is not an ordinary file');
    const checksum = digest(readFileSync(path));
    if (files) receipt.files[name] = checksum;
    else if (receipt.files[name] !== checksum) throw new Error(`Artifact checksum mismatch: ${name}`);
  }
  return receipt;
}

export function checkReleaseArtifacts(directory, plan) {
  validateOriginalPlan(plan);
  const receipt = inspectArtifact(directory, plan);
  for (const name of ['plan.json', 'package.tgz', 'idocs-darwin-arm64.tar.gz', 'idocs-darwin-arm64.sha256']) {
    if (!receipt.files[name]) throw new Error(`Missing required artifact: ${name}`);
  }
  return receipt;
}

export async function lintRange(context) {
  if (configuration.requireBaseline && !context.lastRelease.gitHead) throw new Error('Published baseline is missing; refusing an unexpected first release');
  await validateSemantics({}, {...context, env: {...context.env, RELEASE_TOOLS: here}});
}

function analysisPlugins(observe) {
  return [
    { analyzeCommits: async (_options, context) => { await lintRange(context); observe(context); return null; } },
    { analyzeCommits: (options, context) => analyzeCommits({ ...configuration.analyzer, ...options }, { ...context, env: { ...context.env, RELEASE_TOOLS: here } }) },
    { generateNotes: (options, context) => generateNotes({ ...configuration.notes, ...options }, { ...context, env: { ...context.env, RELEASE_TOOLS: here }, options: { ...context.options, repositoryUrl: 'https://github.com/RbBtSn0w/Apple-iDocs.git' } }) },
  ];
}

export async function runAnalysis(source = root) {
  const candidate = git(source, 'rev-parse', 'HEAD');
  const temporary = mkdtempSync(join(tmpdir(), 'idocs-release-analysis-'));
  const mirror = join(temporary, 'mirror.git');
  const checkout = join(temporary, 'candidate');
  // Only local Git is reachable in planning. In particular no service token is inherited.
  const env = Object.fromEntries(['PATH', 'HOME', 'TMPDIR', 'LANG'].filter((key) => process.env[key]).map((key) => [key, process.env[key]]));
  env.CI = 'false';
  env.GIT_CONFIG_NOSYSTEM = '1';
  env.GIT_CONFIG_GLOBAL = '/dev/null';
  env.GIT_TERMINAL_PROMPT = '0';
  let observed;
  try {
    execFileSync('git', ['clone', '--mirror', '--no-hardlinks', source, mirror], { env, stdio: 'pipe' });
    execFileSync('git', ['--git-dir', mirror, 'update-ref', 'refs/heads/main', candidate], { env });
    execFileSync('git', ['clone', '--no-hardlinks', '--branch', 'main', mirror, checkout], { env, stdio: 'pipe' });
    const result = await semanticRelease({ ...configuration, repositoryUrl: pathToFileURL(mirror).href, dryRun: true, ci: false, plugins: analysisPlugins((context) => { observed = baseline(context); }) }, { cwd: checkout, env, stdout: process.stdout, stderr: process.stderr });
    if (!observed) throw new Error('Release analysis did not complete; false is not proof of no-op');
    return { schema: 1, candidate, baseline: observed, next: result ? next(result) : null, notes: result?.nextRelease?.notes ?? null, configuration: configurationDigest() };
  } finally { rmSync(temporary, { recursive: true, force: true }); }
}

// Recovery trusts the original immutable handoff, never the current checkout's
// version or configuration. Provenance is validated by the read-only input job.
export function recoveryPlan(directory, candidate) {
  const plan = JSON.parse(readFileSync(join(directory, 'plan.json')));
  validateOriginalPlan(plan);
  if (!/^[a-f0-9]{40}$/.test(candidate || '') || plan.candidate !== candidate
      || !plan.next || !/^\d+\.\d+\.\d+$/.test(plan.next.version)
      || plan.next.gitTag !== `v${plan.next.version}`) throw new Error('Invalid original recovery candidate');
  checkReleaseArtifacts(directory, plan);
  return plan;
}

export async function publish(directory) {
  checkEntrypoint(process.env.GITHUB_REF, process.env.GITHUB_EVENT_NAME);
  if (process.env.RELEASE_ENABLED !== 'true') throw new Error('Release activation is disabled');
  const plan = JSON.parse(readFileSync(join(directory, 'plan.json')));
  if (!plan.next || plan.candidate !== process.env.GITHUB_SHA || git(root, 'rev-parse', 'HEAD') !== plan.candidate) throw new Error('Invalid release candidate');
  checkReleaseArtifacts(directory, plan);
  const repository = process.env.GITHUB_REPOSITORY;
  if (repository !== 'RbBtSn0w/Apple-iDocs') throw new Error('Wrong release repository');
  const live = execFileSync('gh', ['api', `repos/${repository}/git/ref/heads/main`, '--jq', '.object.sha'], { encoding: 'utf8', timeout: 30000 }).trim();
  if (!live || live !== plan.candidate) throw new Error('Main changed or could not be read; verify a fresh candidate');
  const { publishRegistries } = await import('./registries.mjs');
  const github = await import('@semantic-release/github');
  const result = await semanticRelease({ ...configuration, repositoryUrl: `https://github.com/${repository}.git`, ci: true, plugins: [
    ...analysisPlugins(() => {}),
    { verifyRelease: async (_options, context) => {
      checkPlan(plan, { candidate: git(root, 'rev-parse', 'HEAD'), baseline: baseline(context), next: next(context), configuration: configurationDigest(), notes: plan.notes });
      checkReleaseArtifacts(directory, plan);
    }, prepare: async (_options, context) => {
      if (typeof plan.notes !== 'string') throw new Error('Original release notes are unavailable');
      checkPlan(plan, {...plan, notes: context.nextRelease.notes});
    } },
    [{ ...github }, { assets: [join(directory, 'idocs-darwin-arm64.tar.gz'), join(directory, 'idocs-darwin-arm64.sha256'), join(directory, 'package.tgz'), join(directory, 'artifact.json'), join(directory, 'plan.json')] }],
    { publish: async () => { await publishRegistries(directory, plan); return { name: 'npmjs and GitHub Packages' }; } },
  ] }, { cwd: root, env: process.env });
  if (!result) throw new Error('Planned release became stale/already released; inspect target states');
  if (process.env.GITHUB_OUTPUT) writeFileSync(process.env.GITHUB_OUTPUT, `version=${result.nextRelease.version}\nreleased=true\nnative_sha256=${checkReleaseArtifacts(directory,plan).files['idocs-darwin-arm64.tar.gz']}\n`, { flag: 'a' });
}

export async function recover(directory, {phase = process.env.RECOVERY_PHASE || 'all', target = process.env.RECOVERY_TARGET} = {}) {
  checkEntrypoint(process.env.GITHUB_REF, process.env.GITHUB_EVENT_NAME);
  if (process.env.RELEASE_ENABLED !== 'true') throw new Error('Release activation is disabled');
  if (!['prepare', 'preflight', 'registry', 'finalize', 'all'].includes(phase)) throw Error('Invalid recovery phase');
  if (['preflight', 'registry'].includes(phase) && !['npm', 'github-packages'].includes(target)) throw Error('Missing recovery target');
  const input = resolve(directory);
  const plan = recoveryPlan(input, process.env.RECOVERY_CANDIDATE);
  if (['prepare', 'all'].includes(phase)) {
    execFileSync('python3', [join(here, 'recovery.py'), '--directory', input], {stdio: 'inherit', timeout: 300000});
    startRecoveryObservationBudget(process.env);
  }
  if (['preflight', 'registry', 'all'].includes(phase)) {
    const {publishRegistries} = await import('./registries.mjs');
    await publishRegistries(input, plan, {recovery: true, observationBudget: recoveryObservationBudget(process.env), target, preflight: phase === 'preflight'});
  }
  if (['finalize', 'all'].includes(phase)) {
    const receipt = JSON.parse(readFileSync(join(input, 'registries.json')));
    const integrity = `sha512-${createHash('sha512').update(readFileSync(join(input, 'package.tgz'))).digest('base64')}`;
    for (const name of ['npm', 'github']) {
      const value = receipt.receipts?.[name];
      if (receipt.registries?.[name] !== 'verified' || value?.status !== 'completed' || value.bytes_verified !== true || value.channel_blocked !== false
          || value.candidate_sha !== plan.candidate || value.version !== plan.next.version || value.integrity !== integrity
          || !Number.isFinite(Date.parse(value.channel_observed_at))) throw Error(`Recovery target remains incomplete: ${name}`);
      assertNpmReceiptConfirmed({name:'@rbbtsn0w/idocs',candidate_sha:plan.candidate,version:plan.next.version,integrity},value);
    }
    if (process.env.GITHUB_OUTPUT) writeFileSync(process.env.GITHUB_OUTPUT, `version=${plan.next.version}\nreleased=true\nnative_sha256=${checkReleaseArtifacts(input,plan).files['idocs-darwin-arm64.tar.gz']}\n`, {flag: 'a'});
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [command, directory] = process.argv.slice(2);
  try {
    if (command === 'plan') {
      checkEntrypoint(process.env.GITHUB_REF, process.env.GITHUB_EVENT_NAME);
      const plan = await runAnalysis();
      if (plan.candidate !== process.env.GITHUB_SHA) throw new Error('Plan candidate does not match event SHA');
      writeFileSync(join(directory, 'plan.json'), JSON.stringify(plan, null, 2) + '\n');
      if (process.env.GITHUB_OUTPUT) writeFileSync(process.env.GITHUB_OUTPUT, `needed=${Boolean(plan.next)}\nversion=${plan.next?.version ?? ''}\n`, { flag: 'a' });
    } else if (command === 'publish') await publish(resolve(directory));
    else if (command === 'recover') await recover(directory);
    else if (command === 'seal') {
      const plan = JSON.parse(readFileSync(join(directory, 'plan.json')));
      writeFileSync(join(directory, 'artifact.json'), JSON.stringify(inspectArtifact(directory, plan, ['plan.json', 'package.tgz', 'idocs-darwin-arm64.tar.gz', 'idocs-darwin-arm64.sha256']), null, 2) + '\n');
    } else throw new Error('Usage: release.mjs plan|publish|seal DIRECTORY');
  } catch (error) { console.error(error); process.exitCode = 1; }
}
