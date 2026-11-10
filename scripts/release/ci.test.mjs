import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
const tools = process.env.RELEASE_TOOLS || fileURLToPath(new URL('./', import.meta.url));
const yaml = createRequire(join(tools, 'package.json'))('yaml');
const root = fileURLToPath(new URL('../../', import.meta.url));
test('ordinary CI checks the real release composition before building the product', () => {
  const ci = yaml.parse(readFileSync(join(root, '.github/workflows/ci.yml'), 'utf8'));
  const steps = ci.jobs['build-and-test'].steps;
  const index = steps.findIndex(step => step.id === 'release_contracts');
  assert.ok(index >= 0, 'Ordinary PR/main CI must validate actual release configuration');
  assert.ok(index < steps.findIndex(step => step.name === 'Build CLI'));
  const step = steps[index];
  assert.ok(!step.if && !step['continue-on-error']);
  const regression = steps.find(step => step.name === 'Verify release configuration');
  assert.equal(regression.env?.RELEASE_TOOLS, step.env.RELEASE_TOOLS);
  const env = {...process.env, RELEASE_TOOLS: tools};
  delete env.NODE_TEST_CONTEXT;
  const result = spawnSync('bash', ['-eu', '-o', 'pipefail', '-c', step.run], {cwd: root, env, encoding: 'utf8', timeout: 30000});
  assert.equal(result.status, 0, result.stderr + result.stdout);
});

test('every release regression caller receives the parser after it is provisioned', () => {
  for (const file of ['ci.yml', 'release.yml']) {
    const workflow = yaml.parse(readFileSync(join(root, '.github/workflows', file), 'utf8'));
    const steps = workflow.jobs[file === 'ci.yml' ? 'build-and-test' : 'verify'].steps;
    const parser = steps.find(step => step.run?.includes('cadence.mjs check'));
    const provision = steps.findIndex(step => step.run?.includes('npm ci --prefix scripts/release'));
    assert.equal(JSON.parse(readFileSync(new URL('./package.json', import.meta.url))).dependencies.yaml, '2.9.1');
    assert.ok(parser.env.RELEASE_TOOLS);
    const callers = steps.filter(step => /test-release-config\.sh|scripts\/release\/\*\.test\.mjs/.test(step.run || ''));
    assert.ok(callers.length > 0);
    for (const regression of callers) {
      assert.equal(regression.env?.RELEASE_TOOLS, parser.env.RELEASE_TOOLS, regression.name);
      assert.ok(provision >= 0 && provision < steps.indexOf(regression), regression.name);
    }
  }
});
