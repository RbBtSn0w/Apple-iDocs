import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

test('release packaging regenerates graph after a test-only workspace and reuses final archive', () => {
  const temporary = mkdtempSync(join(tmpdir(), 'idocs-package-test-'));
  try {
    const bin = join(temporary, 'bin'); mkdirSync(bin);
    const products = join(temporary, 'derived/Build/Products/Release'); mkdirSync(products, { recursive: true });
    writeFileSync(join(products, 'idocs'), '#!/bin/sh\necho fixture\n', { mode: 0o755 });
    writeFileSync(join(bin, 'tuist'), '#!/bin/sh\nprintf "%s\\n" "$*" > "$COMMAND_LOG"\n', { mode: 0o755 });
    writeFileSync(join(bin, 'xcodebuild'), '#!/bin/sh\ntest "$(cat "$COMMAND_LOG")" = "generate --no-open"\n', { mode: 0o755 });
    const output = join(temporary, 'output');
    execFileSync('bash', [new URL('../release-package.sh', import.meta.url).pathname, '1.10.1', output], { env: { ...process.env, PATH: bin + ':' + process.env.PATH, COMMAND_LOG: join(temporary, 'commands'), IDOCS_RELEASE_DERIVED_DATA: join(temporary, 'derived'), IDOCS_RELEASE_BUILD_LOG: join(temporary, 'build.log') }, stdio: 'pipe' });
    assert.equal(readFileSync(join(output, 'idocs-darwin-arm64/idocs.version'), 'utf8').trim(), '1.10.1');
    const extracted = execFileSync('tar', ['-xOzf', join(output, 'idocs-darwin-arm64.tar.gz'), 'idocs-darwin-arm64/idocs.version'], { encoding: 'utf8' });
    assert.equal(extracted.trim(), '1.10.1');
  } finally { rmSync(temporary, { recursive: true, force: true }); }
});
