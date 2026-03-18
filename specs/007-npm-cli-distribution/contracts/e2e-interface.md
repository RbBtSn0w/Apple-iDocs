# Contract: E2E CLI Validation

## E2E Entry Points

Two install/registration paths are mandatory:

1. **Link path**
   - `npm --prefix npm run link-local`
   - `(cd npm && npm link)`
2. **Pack path**
   - `(cd npm && npm pack)`
   - local install from generated `idocs-cli-<version>.tgz`
   - local binary injection via `link-local`

## Correctness Criteria (Structured Assertions)

E2E validates structure and behavior, not full-text snapshots:

- exit code correctness (`0` for core success paths)
- help contract presence (`USAGE: idocs <subcommand>`)
- source observability:
  - `search` output includes `source:`
  - `fetch` output includes `[source:`
- minimal payload structure:
  - `fetch` output contains Markdown heading
  - `list` output contains documentation paths

## Reference-Derived Strategy

Borrowed testing ideas:

- **apple-docs-mcp style**: resilience-oriented command checks, fallback-safe success flow, stable error/success semantics.
- **sosumi.ai style**: output structure and render-readability checks for returned documentation.

No runtime dependency on those external projects is required for iDocs E2E.
