import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { cleanupConsumer } from './verify-package.mjs';

test('cleanup before listen preserves the original failure and removes temporary files', async () => {
  const temporary = mkdtempSync(join(tmpdir(), 'idocs-cleanup-'));
  const server = createServer();
  let closes = 0;
  const originalClose = server.close.bind(server);
  server.close = (...args) => { closes++; return originalClose(...args); };
  const original = new Error('original extraction failure');
  await assert.rejects(async () => {
    try { throw original; } finally { await cleanupConsumer(server, temporary); }
  }, error => error === original);
  assert.equal(closes, 0);
  assert.equal(existsSync(temporary), false);
});

test('cleanup closes a listening server and removes temporary files', async () => {
  const temporary = mkdtempSync(join(tmpdir(), 'idocs-cleanup-'));
  const server = createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  await cleanupConsumer(server, temporary);
  assert.equal(server.listening, false);
  assert.equal(existsSync(temporary), false);
});

test('cleanup removes temporary files even when close reports an unexpected error', async () => {
  const temporary = mkdtempSync(join(tmpdir(), 'idocs-cleanup-'));
  const failure = new Error('server close failure');
  const server = { listening: true, close(callback) { callback(failure); } };
  await assert.rejects(cleanupConsumer(server, temporary), error => error === failure);
  assert.equal(existsSync(temporary), false);
});
