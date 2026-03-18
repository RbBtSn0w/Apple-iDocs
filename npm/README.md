# idocs-cli (npm wrapper)

This package distributes the `idocs` Swift CLI through npm.

## Install

```bash
npm install -g idocs-cli
```

By default, `postinstall` downloads `idocs-darwin-arm64.tar.gz` from:

`https://github.com/OWNER/REPO/releases/download/v{version}`

Override the release URL if needed:

```bash
export IDOCS_RELEASE_BASE_URL="https://github.com/<owner>/<repo>/releases/download/v{version}"
npm install -g idocs-cli
```

The archive is expected to contain:
- `idocs-darwin-arm64/idocs`
- `idocs-darwin-arm64/Frameworks/*.framework`

## Local development

```bash
./scripts/tuist-silent.sh build iDocs
npm --prefix npm run link-local
npm --prefix npm link
idocs --help
```

## Strict install mode

Set `IDOCS_NPM_STRICT_INSTALL=1` to fail install when binary download fails.
