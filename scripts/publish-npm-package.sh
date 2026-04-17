#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${IDOCS_NPM_PACKAGE_DIR:-$ROOT_DIR/npm}"
TARGET_REGISTRY="${1:-}"

if [[ "$TARGET_REGISTRY" != "npmjs" && "$TARGET_REGISTRY" != "github" ]]; then
  echo "Usage: $0 [npmjs|github]" >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_DIR/package.json" ]]; then
  echo "package.json not found at $PACKAGE_DIR/package.json" >&2
  exit 1
fi

PACKAGE_NAME="$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).name" "$PACKAGE_DIR/package.json")"
PACKAGE_VERSION="$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).version" "$PACKAGE_DIR/package.json")"
PACKAGE_SCOPE="${PACKAGE_NAME%%/*}"
TEMP_NPMRC_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEMP_NPMRC_DIR"
}

trap cleanup EXIT
export NPM_CONFIG_USERCONFIG="$TEMP_NPMRC_DIR/.npmrc"
: > "$NPM_CONFIG_USERCONFIG"

package_exists() {
  local registry="$1"
  local output=""
  local status=0

  set +e
  output="$(npm view "${PACKAGE_NAME}@${PACKAGE_VERSION}" version --registry "$registry" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    return 0
  fi

  if [[ "$output" == *"E404"* || "$output" == *"404 Not Found"* ]]; then
    return 1
  fi

  echo "Failed to check ${PACKAGE_NAME}@${PACKAGE_VERSION} on ${registry}." >&2
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" >&2
  fi
  return 2
}

cd "$PACKAGE_DIR"

case "$TARGET_REGISTRY" in
  npmjs)
    NPMJS_REGISTRY="https://registry.npmjs.org"
    if [[ -n "${NODE_AUTH_TOKEN:-}" ]]; then
      npm config set "//registry.npmjs.org/:_authToken" "$NODE_AUTH_TOKEN" >/dev/null
    fi

    if package_exists "$NPMJS_REGISTRY"; then
      package_exists_status=0
    else
      package_exists_status=$?
    fi
    case "$package_exists_status" in
      0)
        echo "${PACKAGE_NAME}@${PACKAGE_VERSION} already exists on npmjs.org; skipping publish."
        exit 0
        ;;
      1)
        ;;
      *)
        exit "$package_exists_status"
        ;;
    esac

    npm publish --provenance --access public --registry "$NPMJS_REGISTRY"
    ;;
  github)
    if [[ "$PACKAGE_SCOPE" == "$PACKAGE_NAME" ]]; then
      echo "GitHub Packages publish requires a scoped package name." >&2
      exit 1
    fi

    if [[ -z "${NODE_AUTH_TOKEN:-}" ]]; then
      echo "NODE_AUTH_TOKEN is required for GitHub Packages publish." >&2
      exit 1
    fi

    GITHUB_PACKAGES_REGISTRY="https://npm.pkg.github.com"
    npm config set "${PACKAGE_SCOPE}:registry" "$GITHUB_PACKAGES_REGISTRY" >/dev/null
    npm config set "//npm.pkg.github.com/:_authToken" "$NODE_AUTH_TOKEN" >/dev/null

    if package_exists "$GITHUB_PACKAGES_REGISTRY"; then
      package_exists_status=0
    else
      package_exists_status=$?
    fi
    case "$package_exists_status" in
      0)
        echo "${PACKAGE_NAME}@${PACKAGE_VERSION} already exists on GitHub Packages; skipping publish."
        exit 0
        ;;
      1)
        ;;
      *)
        exit "$package_exists_status"
        ;;
    esac

    npm publish --registry "$GITHUB_PACKAGES_REGISTRY"
    ;;
esac
