# Contract: CLI Interface (idocs)

## Commands

### `idocs search <query>`
- Delegates to layered retrieval policy for search.
- Success output includes result fields and source hit.
- Supports `--json` for agent-facing machine-readable output.
- Supports `--caller <opaque-id>` for agent or workflow attribution.
- Failure output uses standardized error categories.

### `idocs fetch <id>`
- Delegates to layered retrieval policy for fetch.
- Success output returns body content and includes source in metadata/context output.
- Supports `--json` for agent-facing machine-readable output.
- Supports `--caller <opaque-id>` for agent or workflow attribution.
- Failure output uses standardized error categories.

### `idocs list [--category <category>]`
- Lists technology catalog entries from the adapter contract.
- Supports optional category filtering.
- Supports `--json` for agent-facing machine-readable output.
- Supports `--caller <opaque-id>` for agent or workflow attribution.
- Failure output uses standardized error categories.

## Environment Contract

- `IDOCS_CACHE_PATH` overrides the default CLI disk-cache root.
- `IDOCS_USAGE_LOG_PATH` overrides the default CLI usage JSONL path.
- Local performance gates may set both variables to isolate benchmark artifacts from day-to-day CLI usage.

## JSON Contract

When `--json` is set, `stdout` contains one JSON payload with at least:
- `command`
- `caller`
- `source`
- `duration_ms`
- `result_count`
- `selected_paths`
- `exit_category`

Command-specific selectors:

- `search` includes `query`
- `fetch` includes `id`
- `list` may include `category`

`fetch` responses also include the rendered Markdown `body` payload.

## Error Contract

CLI error categories remain stable:
- `OK`
- `NOT_FOUND`
- `NETWORK`
- `PARSING`
- `UNAUTHORIZED`
- `CONFIG`
- `VERSION_MISMATCH`
- `INTERNAL`

Non-zero exit code is returned on failures.
