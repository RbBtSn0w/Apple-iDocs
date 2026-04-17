# @rbbtsn0w/idocs (npm wrapper)

This package distributes the `idocs` Swift CLI through npm.

## Install

```bash
npm install -g @rbbtsn0w/idocs
idocs --help
```

For normal users, this is the complete install flow. `postinstall` downloads the matching `idocs-darwin-arm64.tar.gz` asset from GitHub Releases automatically.

If install fails, rerun the install and inspect the npm output. A failed download should be treated as a release packaging problem, not as an expected manual setup step.

## Advanced: Alternate Release Mirror

`IDOCS_RELEASE_BASE_URL` is only for internal mirrors or custom release hosting. It is not required for the normal npm install path.

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
