# Quickstart: npm Distribution for iDocs CLI

## 1) Build local CLI binary

```bash
./scripts/tuist-silent.sh build iDocs
```

## 2) Local npm registration

```bash
npm --prefix npm run link-local
npm --prefix npm link
idocs --help
```

## 3) npm package smoke check

```bash
npm --prefix npm pack
TMP_DIR="$(mktemp -d)"
npm --prefix "$TMP_DIR" init -y
npm --prefix "$TMP_DIR" i "$(pwd)/npm/idocs-cli-0.1.0.tgz"
IDOCS_LOCAL_BINARY="$HOME/Library/Developer/Xcode/DerivedData/iDocs-codex/Build/Products/Debug/idocs" \
  npm --prefix "$TMP_DIR/node_modules/idocs-cli" run link-local
"$TMP_DIR/node_modules/.bin/idocs" --help
```

## 4) Release asset generation

```bash
./scripts/release-package.sh
```

Expected files:
- `dist/release/v0.1.0/idocs-darwin-arm64.tar.gz`
- `dist/release/v0.1.0/idocs-darwin-arm64.sha256`
