# iDocs OpenTelemetry Design

## Summary

Instrument the `idocs` CLI with OpenTelemetry traces using the same edge-gateway pattern already proven in `gh-address-cr-skill`:

- export traces to the self-managed Cloudflare Worker gateway
- keep the CLI credential-free
- preserve CLI behavior and exit semantics under all telemetry failures
- model the CLI as one root invocation span with a bounded set of child spans

This change is intentionally trace-only. Metrics and logs stay out of scope for the first slice.

## Goals

- Produce one trace per `idocs` invocation
- Propagate parent context from `TRACEPARENT` / `traceparent`
- Preserve current text/JSON output contracts
- Keep telemetry fail-open and bounded for short-lived CLI processes
- Reuse semantic boundaries that already exist in the codebase: CLI command, adapter call, and pipeline execution

## Non-Goals

- No metrics or logs in this slice
- No automatic `URLSession` instrumentation for Apple/sosumi requests
- No backend credential handling in the CLI
- No change to public CLI flags or required environment variables

## Gateway Contract

- Default traces endpoint: `https://telemetry-gateway.hamiltonsnow.workers.dev/v1/traces`
- Override precedence:
  1. `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
  2. `OTEL_EXPORTER_OTLP_ENDPOINT` + `/v1/traces`
  3. default Cloudflare Worker endpoint
- Opt-out:
  - `DISABLE_TELEMETRY=1`
  - `DO_NOT_TRACK=1`

The Worker remains responsible for any backend credential injection. The CLI sends OTLP/HTTP directly to the gateway only.

## Span Model

### Root span

- name: `{process.executable.name}` (e.g. `idocs`)
- kind: `internal`

Root attributes:

- `service.name = idocs`
- `service.version = <current CLI version>`
- `service.namespace = com.snow`
- `deployment.environment = test` only when explicitly configured for tests
- `process.command`
- `process.command_args`
- `process.executable.name`
- `process.pid`
- `process.parent_pid`

### Child spans

- `idocs.command.search`
- `idocs.command.resolve`
- `idocs.command.fetch`
- `idocs.command.list`
- `idocs.adapter`
- `idocs.search.pipeline`
- `idocs.fetch.pipeline`
- `idocs.resolve.pipeline`

Command span attributes:

- `idocs.command.name`
- `idocs.output.format`
- `idocs.caller`
- `process.exit.code`
- `error.type` on propagated failures

Adapter span attributes:

- `idocs.operation.name`
- `idocs.locale`
- `idocs.category_filter` when applicable

Pipeline span attributes:

- `idocs.query`
- `idocs.path`
- `idocs.result.count`
- `idocs.source`

### Events

Stage-by-stage search/fetch/resolve diagnostics remain events instead of further child spans. This keeps the trace shape readable and prevents stage noise from dominating short CLI invocations.

Event attributes:

- `idocs.stage.name`
- `idocs.stage.status`
- `idocs.stage.reason`
- `idocs.result.count`
- `idocs.source`
- `idocs.query_attempt`
- `idocs.path`

## Code Structure

Add a new shared target:

- `Sources/iDocsTelemetry/`

Responsibilities:

- OTLP/HTTP exporter setup
- resource construction
- endpoint resolution
- trace-context extraction
- root/child span helpers
- fail-open shutdown

Layer ownership:

- `Main.swift`: root invocation span and bounded shutdown
- `CLIExecutor.swift`: command spans and command-level exit/error attributes
- `DefaultDocumentationAdapter.swift`: adapter span
- `SearchDocsTool.swift` / `FetchDocTool.swift` / `ResolveDocsTool.swift`: pipeline spans plus existing diagnostics as events

## Failure Policy

- Telemetry initialization failure must not change CLI output or exit behavior
- Exporter failures must not write to CLI stderr
- Shutdown/flush must be bounded
- Missing parent context must fall back to a new root trace

## Testing

### Test Intent

#### Risk

This change touches CLI process control flow, exit semantics, and cross-layer instrumentation boundaries. A broken implementation could change user-visible command behavior, lose parent/child relationships, or block short-lived CLI invocations during export.

#### Why Automation

Manual smoke checks are insufficient for verifying span parentage, endpoint precedence, opt-out behavior, and fail-open shutdown without regressions.

#### Why Existing Tests Insufficient

Current tests validate CLI outputs, adapter contracts, and diagnostics, but they do not cover any telemetry bootstrap, span hierarchy, exporter config, or parent-context propagation.

#### Chosen Layer

Unit and focused integration tests. This is the smallest effective layer for provider/bootstrap behavior, command-span parentage, and output non-regression.

#### Fragility Analysis

Tests avoid timing-sensitive network export and rely on an in-memory exporter. Assertions focus on stable span names, parentage, and attributes instead of internal SDK implementation details.

#### If Omitted

We could ship a CLI that silently drops traces, emits malformed parentage, or changes command behavior under telemetry failures without noticing locally.

### Planned coverage

- endpoint resolution precedence
- opt-out returns no-op behavior
- parent context extraction from `traceparent`
- root -> command -> pipeline parentage
- command exit/error attributes
- fail-open shutdown/export path
- no regression in current JSON/text CLI outputs
