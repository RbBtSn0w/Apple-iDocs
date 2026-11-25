import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SpanKind } from '@opentelemetry/api';
import { execPreview, spawnPreview, withPreviewTrace } from './telemetry.mjs';

test('preview CLI and subprocess spans preserve process results without sensitive inputs', async () => {
  const finished = [];
  let shutdown = false;
  const exporter = {
    export(spans, done) { finished.push(...spans); done({ code: 0 }); },
    async shutdown() { shutdown = true; },
  };
  const privateText = '/private/path/not-for-telemetry';
  await assert.rejects(withPreviewTrace('idocs-pr-preview-test', async () => {
    assert.equal(execPreview(process.execPath, ['-e', 'process.stdout.write("ok")', privateText], { encoding: 'utf8' }), 'ok');
    const result = spawnPreview(process.execPath, ['-e', 'process.exit(7)'], { env: { SOME_TOKEN: privateText } });
    assert.equal(result.status, 7);
    throw new Error(privateText);
  }, { exporter, env: {} }), /not-for-telemetry/);
  const root = finished.find(span => span.kind === SpanKind.INTERNAL);
  const children = finished.filter(span => span.kind === SpanKind.CLIENT);
  assert.equal(root.name, 'idocs-pr-preview-test');
  assert.equal(root.attributes['process.pid'], process.pid);
  assert.equal(root.attributes['process.exit.code'], 1);
  assert.equal(root.attributes['error.type'], 'PreviewCommandError');
  assert.equal(children.length, 2);
  assert.deepEqual(children.map(span => span.attributes['process.exit.code']), [0, 7]);
  assert.equal(children[1].attributes['error.type'], 'SubprocessExit');
  for (const span of children) {
    assert.equal(span.name, 'node');
    assert.equal(span.attributes['process.executable.name'], 'node');
    assert.ok(span.attributes['process.pid'] > 0);
    assert.equal(span.parentSpanContext.spanId, root.spanContext().spanId);
  }
  assert.doesNotMatch(JSON.stringify(finished.map(span => span.attributes)), /not-for-telemetry|SOME_TOKEN/);
  assert.equal(shutdown, true);
});

test('an unresponsive exporter does not prevent failures from returning', { timeout: 3000 }, async () => {
  const exporter = { export() {}, shutdown: () => new Promise(() => {}) };
  await assert.rejects(withPreviewTrace('idocs-pr-preview-test', () => { throw new Error('original failure'); },
    { exporter, maxWait: 20, env: {} }), /original failure/);
});
