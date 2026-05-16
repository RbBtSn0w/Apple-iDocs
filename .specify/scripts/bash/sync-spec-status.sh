#!/usr/bin/env bash

set -euo pipefail

STATUS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "ERROR: --status requires a value" >&2
                exit 1
            fi
            STATUS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --status <status>"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$1'" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$STATUS" ]]; then
    echo "ERROR: --status is required" >&2
    exit 1
fi

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

_paths_output=$(get_feature_paths) || {
    echo "ERROR: Failed to resolve feature paths" >&2
    exit 1
}
eval "$_paths_output"
unset _paths_output

if [[ ! -f "$FEATURE_SPEC" ]]; then
    echo "ERROR: Feature spec not found: $FEATURE_SPEC" >&2
    exit 1
fi

CURRENT_STATUS="$(
    sed -n 's/^\*\*Status\*\*: \(.*\)  *$/\1/p' "$FEATURE_SPEC" | head -n 1
)"

if [[ "$CURRENT_STATUS" == "Abandoned" && "$STATUS" != "Abandoned" ]]; then
    printf '{"feature_spec":"%s","previous_status":"%s","status":"%s","preserved":true}\n' \
        "$FEATURE_SPEC" "$CURRENT_STATUS" "$CURRENT_STATUS"
    exit 0
fi

if [[ -z "$CURRENT_STATUS" ]]; then
    echo "ERROR: Could not find status line in $FEATURE_SPEC" >&2
    exit 1
fi

tmp_file="$(mktemp)"
awk -v status="$STATUS" '
    BEGIN { updated = 0 }
    /^\*\*Status\*\*:/ && updated == 0 {
        print "**Status**: " status "  "
        updated = 1
        next
    }
    { print }
    END {
        if (updated == 0) {
            exit 2
        }
    }
' "$FEATURE_SPEC" > "$tmp_file" || {
    rm -f "$tmp_file"
    echo "ERROR: Failed to update status in $FEATURE_SPEC" >&2
    exit 1
}

mv "$tmp_file" "$FEATURE_SPEC"

printf '{"feature_spec":"%s","previous_status":"%s","status":"%s","preserved":false}\n' \
    "$FEATURE_SPEC" "$CURRENT_STATUS" "$STATUS"
