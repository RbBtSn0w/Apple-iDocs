# Contract: CLI Interface (idocs)

## Commands

### `idocs search <query>`
- Delegates to layered retrieval policy for search.
- Success output includes result fields and source hit.
- Failure output uses standardized error categories.

### `idocs fetch <id>`
- Delegates to layered retrieval policy for fetch.
- Success output returns body content and includes source in metadata/context output.
- Failure output uses standardized error categories.

### `idocs list [--category <category>]`
- Lists technology catalog entries from the adapter contract.
- Supports optional category filtering.
- Failure output uses standardized error categories.

## Error Contract

CLI error categories remain stable:
- `NOT_FOUND`
- `NETWORK`
- `PARSING`
- `UNAUTHORIZED`
- `CONFIG`
- `VERSION_MISMATCH`
- `INTERNAL`

Non-zero exit code is returned on failures.
