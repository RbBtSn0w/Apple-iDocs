import { tarballName } from './artifact.mjs';
import { fullSha, packageName, positiveId } from './version.mjs';

export const marker = '<!-- idocs-pr-preview -->';
const verifiedMarker = head => `<!-- idocs-verified-registry:${head} -->`;
const same = (a, b) => a?.toLowerCase() === b.toLowerCase();
export const artifactName = ({ pr, head, attempt }) => `idocs-pr-${pr}-${head}-attempt-${attempt}`;

export function isCurrent(pr, head, repository) {
  return pr.state === 'open' && pr.base.ref === 'main' && pr.head.sha === head &&
    same(pr.base.repo?.full_name, repository) && same(pr.head.repo?.full_name, repository);
}

export async function selectArtifact(github, { owner, repo, sourceRun }) {
  const run_id = Number(sourceRun);
  if (!positiveId.test(sourceRun) || !Number.isSafeInteger(run_id)) throw new Error('Enter a positive CI run ID');
  const repository = `${owner}/${repo}`;
  const { data: run } = await github.rest.actions.getWorkflowRun({ owner, repo, run_id });
  if (run.id !== run_id || run.path !== '.github/workflows/ci.yml' || run.event !== 'pull_request' ||
      run.conclusion !== 'success' || !same(run.repository?.full_name, repository) ||
      !same(run.head_repository?.full_name, repository) || !fullSha.test(run.head_sha) || run.pull_requests?.length !== 1 ||
      !Number.isSafeInteger(run.run_attempt) || run.run_attempt < 1) {
    throw new Error('Expected a successful same-repository iDocs CI run with one pull request');
  }
  const [{ number, head }] = run.pull_requests;
  if (!Number.isSafeInteger(number) || number < 1 || head.sha !== run.head_sha) throw new Error('Invalid source PR identity');
  const { data: pr } = await github.rest.pulls.get({ owner, repo, pull_number: number });
  if (!isCurrent(pr, run.head_sha, repository)) throw new Error('The source run is not for the current PR head');

  const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRun, { owner, repo, run_id, filter: 'all' });
  const packers = jobs.filter(job => job.run_id === run_id && job.name === 'iDocs PR preview package' && job.conclusion === 'success' &&
    Number.isSafeInteger(job.run_attempt) && job.run_attempt > 0 && job.run_attempt <= run.run_attempt &&
    job.steps?.some(step => step.name === 'Upload verified preview' && step.conclusion === 'success'));
  const artifacts = await github.paginate(github.rest.actions.listWorkflowRunArtifacts, { owner, repo, run_id });
  const attempts = [...new Set(packers.map(job => job.run_attempt))].sort((a, b) => b - a);
  for (const attempt of attempts) {
    const name = artifactName({ pr: number, head: run.head_sha, attempt });
    const matches = artifacts.filter(artifact => artifact.name === name && artifact.expired === false);
    if (!matches.length) continue;
    const [{ id }] = matches;
    if (matches.length !== 1 || !Number.isSafeInteger(id) || id < 1 || packers.filter(job => job.run_attempt === attempt).length !== 1) {
      throw new Error('Ambiguous preview upload');
    }
    return { pr: String(number), head: run.head_sha, run: String(run_id), attempt: String(attempt), artifact: String(id) };
  }
  throw new Error('Verified preview artifact is missing or expired');
}

export function renderCard({ repository, receipt, artifact, registry = {}, server = 'https://github.com' }) {
  const root = `${server}/${repository}`;
  const { pr, head, run, attempt, sha256, version, baseline } = receipt;
  const runURL = `${root}/actions/runs/${run}`;
  const exact = `${packageName}@${version}`;
  const flags = `--allow-scripts=${packageName}`;
  const registries = Object.entries(registry).filter(([, status]) => status.available === true);
  const lines = ['### iDocs PR preview', '',
    `Version \`${version}\` · Commit [\`${head}\`](${root}/commit/${head})`, '',
    'Requires Apple Silicon macOS 13+ and Node.js 22.22.2+ (22.x) or 24.15.0+ (24.x) with npm 12.', ''];
  for (const [target, status] of registries) {
    const mirror = target === 'github-packages';
    const label = mirror ? 'GitHub Packages' : 'npmjs';
    const prefix = mirror ? 'NPM_CONFIG_USERCONFIG="$preview_config" ' : '';
    lines.push(`#### ${label}`, '');
    if (mirror) {
      lines.push('Set `GITHUB_PACKAGES_TOKEN` to a token with read access to the package.', '', '```sh',
        'preview_config="$(mktemp)"', 'chmod 600 "$preview_config"',
        'printf \'%s\\n\' \'@rbbtsn0w:registry=https://npm.pkg.github.com\' \'//npm.pkg.github.com/:_authToken=${GITHUB_PACKAGES_TOKEN}\' > "$preview_config"', '```', '');
    }
    lines.push('Try this exact version without changing your global installation:', '', '```sh',
      `${prefix}npm exec --yes ${flags} --package=${exact} -- idocs --version`, '```', '',
      'Install or switch to this exact global version:', '', '```sh',
      `${prefix}npm install --global ${flags} ${exact} && idocs --version`, '```', '',
      status.next ? 'Registry readback observed `next` pointing to this version.' : 'The registry did not confirm `next` pointing to this version.',
      '`next` is a moving tag. Follow it to try whichever preview it points to:', '',
      `\`${prefix}npm exec --yes ${flags} --package=${packageName}@next -- idocs --version\``, '');
    if (mirror) lines.push('Remove the temporary config after use with `rm "$preview_config"`.', '');
  }
  if (!registries.length) lines.push(baseline ? `Artifact preview · npm stable baseline \`${baseline}\`.` : 'Artifact preview · npm stable baseline unavailable.', '');
  lines.push(`[Download the verified ZIP](${runURL}/artifacts/${artifact}) · [Actions verification](${runURL})`, '',
    `Run \`${run}\` · packaging attempt \`${attempt}\` · artifact \`${artifact}\``, '',
    'Extract the ZIP and run the following from its folder. Set a temporary npm prefix to keep the global installation untouched.', '',
    '```sh', `preview_archive="$(pwd -P)/${tarballName}"`, 'preview_prefix="$(mktemp -d)"',
    'shasum -a 256 -c SHA256SUMS &&', '  mkdir -p "$preview_prefix/lib/node_modules" &&',
    '  npm install --global --prefix "$preview_prefix" --offline --allow-scripts="file:$preview_archive" "$preview_archive" &&',
    '  "$preview_prefix/bin/idocs" --version &&', '  "$preview_prefix/bin/idocs" resolve --help', '```', '',
    '<details>', '<summary>Download and verify with GitHub CLI</summary>', '', '```sh', 'preview_dir="$(mktemp -d)"',
    `gh run download ${run} --repo ${repository} --name ${artifactName({ pr, head, attempt })} --dir "$preview_dir" &&`,
    '  cd "$preview_dir" && shasum -a 256 -c SHA256SUMS', '```', '', `SHA-256 \`${sha256}\``, '', '</details>', '');
  return lines.join('\n');
}

export async function updateCard(github, { owner, repo, pr, head, body, published = false }) {
  const repository = `${owner}/${repo}`;
  const issue_number = Number(pr);
  const comments = await github.paginate(github.rest.issues.listComments, { owner, repo, issue_number, per_page: 100 });
  const existing = comments.find(comment => comment.user?.login === 'github-actions[bot]' && comment.body?.startsWith(marker));
  const { data: current } = await github.rest.pulls.get({ owner, repo, pull_number: issue_number });
  if (!isCurrent(current, head, repository)) return 'stale';
  if (!published && existing?.body.includes(verifiedMarker(head))) return 'preserved';
  const message = [marker, published && verifiedMarker(head), body].filter(Boolean).join('\n');
  if (existing?.body === message) return 'unchanged';
  if (existing) {
    await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body: message });
  } else {
    await github.rest.issues.createComment({ owner, repo, issue_number, body: message });
  }
  return existing ? 'updated' : 'created';
}
