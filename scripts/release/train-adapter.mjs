// Fixed product adapters retain native packaging and dual-registry ordering.
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const directory = args => {const at = args.indexOf('--directory'); return at < 0 ? 'release-input' : args[at + 1];};
function product(mode, {cwd, env, args}) {
  return execFileSync(process.execPath, [join(cwd, 'scripts/release/release.mjs'), mode, directory(args)], {cwd, env, stdio: 'inherit'});
}
export function analyze(context) {
  if (Number(context.env.GITHUB_RUN_ATTEMPT || 1) > 1) throw Error(`Analysis rerun stopped: a previous attempt may already have published. Inspect ${context.env.GITHUB_SERVER_URL || 'https://github.com'}/${context.env.GITHUB_REPOSITORY}/actions/runs/${context.env.GITHUB_RUN_ID}; recover the original release or start a new main run.`);
  return product('plan', context);
}
export const seal = context => product('seal', context);
export const publish = context => product('publish', context);
export const recover = context => product('recover', context);
export function report({cwd,env}) {
  execFileSync(process.execPath, [fileURLToPath(new URL('./observe.mjs',import.meta.url))], {cwd,env,stdio:'inherit'});
  const result = JSON.parse(readFileSync(join(cwd,'release-result.json')));
  if (result.verification === 'failed' || result.failure_stage || result.publication === 'failed' || (result.publication === 'partial' && !result.asynchronous)) throw Error('Release outcome is incomplete; inspect the retained result and channel evidence.');
}
