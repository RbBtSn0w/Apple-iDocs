# @rbbtsn0w/idocs (npm wrapper)

This package distributes the `idocs` Swift CLI through npm.

## Install

```bash
npm install -g @rbbtsn0w/idocs --allow-scripts=@rbbtsn0w/idocs
idocs --help
```

npm 12 blocks dependency install scripts by default. The flag permits only iDocs
for this installation; it does not change global policy. For npm 11 or earlier,
omit the flag. `postinstall` downloads the matching `idocs-darwin-arm64.tar.gz`
asset from GitHub Releases automatically. For project-scoped installs, record a
package-specific `allowScripts` policy in the project instead of using this
global-install flag.

If install fails, rerun the install and inspect the npm output. A failed download should be treated as a release packaging problem, not as an expected manual setup step.

## Advanced: Alternate Release Mirror

`IDOCS_RELEASE_BASE_URL` is only for internal mirrors or custom release hosting. It is not required for the normal npm install path.

```bash
export IDOCS_RELEASE_BASE_URL="https://github.com/<owner>/<repo>/releases/download/v{version}"
npm install -g @rbbtsn0w/idocs --allow-scripts=@rbbtsn0w/idocs
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
