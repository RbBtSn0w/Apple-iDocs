// Included only in preview tarballs. Stable packages use the release downloader.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const dist = fileURLToPath(new URL('../dist/', import.meta.url));
const archive = fileURLToPath(new URL('./idocs-darwin-arm64.tar.gz', import.meta.url));
const { version } = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
mkdirSync(dist, { recursive: true });
execFileSync('tar', ['-xzf', archive, '--strip-components', '1', '-C', dist], { stdio: 'inherit' });
if (readFileSync(new URL('../dist/idocs.version', import.meta.url), 'utf8').trim() !== version) {
  throw new Error('The bundled iDocs executable has a different version');
}
