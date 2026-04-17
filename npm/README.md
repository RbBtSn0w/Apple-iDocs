# @rbbtsn0w/idocs (npm wrapper)

This package distributes the `idocs` Swift CLI through npm.

## Install

```bash
npm install -g @rbbtsn0w/idocs
```

By default, `postinstall` downloads `idocs-darwin-arm64.tar.gz` from:

`https://github.com/RbBtSn0w/Apple-iDocs/releases/download/v{version}`

The matching GitHub Release must include that asset. If the download fails, install exits non-zero by default so npm does not leave an unusable `idocs` shim behind.

Override the release URL if needed:

```bash
export IDOCS_RELEASE_BASE_URL="https://github.com/<owner>/<repo>/releases/download/v{version}"
npm install -g @rbbtsn0w/idocs
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

## Non-strict install mode

Set `IDOCS_NPM_STRICT_INSTALL=0` only if you intentionally want to keep the wrapper installed without a binary for local debugging flows.
