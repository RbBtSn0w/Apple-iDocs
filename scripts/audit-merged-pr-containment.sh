#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-main}"
BASE_REF="${BASE_REF:-}"
PR_LIMIT="${PR_LIMIT:-50}"
REPOSITORY="${GITHUB_REPOSITORY:-}"
MERGED_AFTER="${MERGED_AFTER:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/audit-merged-pr-containment.sh

Environment:
  BASE_BRANCH  Branch that must contain merged PR commits. Default: main
  BASE_REF     Optional git ref to inspect instead of origin/$BASE_BRANCH.
  PR_LIMIT     Number of recent merged PRs to inspect. Default: 50
  MERGED_AFTER Optional ISO-8601 timestamp; older merged PRs are ignored.
  GITHUB_REPOSITORY  Optional owner/name repository override for gh.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

GH_BIN="${GH_BIN:-}"
if [[ -z "${GH_BIN}" ]]; then
  if command -v gh >/dev/null 2>&1; then
    GH_BIN="$(command -v gh)"
  elif [[ -x "/opt/homebrew/bin/gh" ]]; then
    GH_BIN="/opt/homebrew/bin/gh"
  fi
fi

if [[ -z "${GH_BIN}" ]]; then
  echo "gh CLI is required." >&2
  exit 127
fi

if [[ -n "${BASE_REF}" ]]; then
  target_ref="${BASE_REF}"
else
  target_ref="origin/${BASE_BRANCH}"
  git fetch origin "${BASE_BRANCH}" --quiet
fi

if ! git rev-parse --verify --quiet "${target_ref}" >/dev/null; then
  echo "Base ref not found: ${target_ref}" >&2
  exit 1
fi

if [[ -n "${REPOSITORY}" ]]; then
  rows="$(
    "${GH_BIN}" pr list --repo "${REPOSITORY}" \
      --state merged \
      --limit "${PR_LIMIT}" \
      --json number,title,baseRefName,mergeCommit,mergedAt,url \
      --jq '.[] | select(.mergeCommit.oid != null) | [.number, .baseRefName, .mergeCommit.oid, .mergedAt, .url, .title] | @tsv'
  )"
else
  rows="$(
    "${GH_BIN}" pr list \
      --state merged \
      --limit "${PR_LIMIT}" \
      --json number,title,baseRefName,mergeCommit,mergedAt,url \
      --jq '.[] | select(.mergeCommit.oid != null) | [.number, .baseRefName, .mergeCommit.oid, .mergedAt, .url, .title] | @tsv'
  )"
fi

missing=0
while IFS=$'\t' read -r number pr_base oid merged_at url title; do
  [[ -n "${number}" ]] || continue

  if [[ -n "${MERGED_AFTER}" && "${merged_at}" < "${MERGED_AFTER}" ]]; then
    continue
  fi

  if git merge-base --is-ancestor "${oid}" "${target_ref}"; then
    continue
  fi

  missing=$((missing + 1))
  echo "::error title=Merged PR not contained in ${target_ref}::#${number} (${pr_base}) ${oid} ${url} ${title}"
done <<< "${rows}"

if (( missing > 0 )); then
  echo "Found ${missing} merged PR commit(s) not contained in ${target_ref}." >&2
  exit 1
fi

echo "All inspected merged PR commits are contained in ${target_ref}."
