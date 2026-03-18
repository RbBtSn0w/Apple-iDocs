# Contract: npm Interface for iDocs CLI

## Package

- Package name: `idocs-cli`
- Bin command: `idocs`
- Platform (v1): `darwin` + `arm64`

## Install Behavior

- `postinstall` attempts to download:
  - `idocs-darwin-arm64.tar.gz`
- Default release URL pattern:
  - `https://github.com/OWNER/REPO/releases/download/v{version}/idocs-darwin-arm64.tar.gz`
- URL override:
  - `IDOCS_RELEASE_BASE_URL` (supports `{version}` placeholder)

## Local Development Behavior

- `npm --prefix npm run link-local` copies a local built binary to `npm/dist/idocs`
- `npm --prefix npm link` registers global `idocs`

## Release Packaging Contract

- `scripts/release-package.sh` outputs:
  - `idocs-darwin-arm64.tar.gz`
  - `idocs-darwin-arm64.sha256`
- Archive content:
  - `idocs-darwin-arm64/idocs`
  - `idocs-darwin-arm64/Frameworks/*.framework`
