# Honeycomb Queries, Boards, and SLO Specification

Status: Adopted  
Applies to: `iDocs` CLI Telemetry v2  
Last updated: 2026-09-14  

This document formalizes the Honeycomb observability assets for iDocs, including dataset schema, Golden Signals query patterns, Service Level Objectives (SLOs), and BubbleUp triage workflows.

---

## 1. Honeycomb Dataset Schema Overview

Telemetry is streamed through the OpenTelemetry gateway (`https://telemetry-gateway.hamiltonsnow.workers.dev/v1/traces`) with `otel-gateway-profile: anonymous-client-v1` into the operator-configured Honeycomb dataset (`idocs`).

### Resource Attributes
- `service.name`: Fixed identifier (`"idocs"` or `"idocs-test"`).
- `service.namespace`: Organization namespace (`"com.snow"`).
- `service.version`: SemVer string from `CLIVersion.current()`.
- `idocs.telemetry.schema.version`: Current schema version (`"2"`).

### Span Dimensions

#### Root Execution Span (`name = "idocs"`, `span.kind = "internal"`)
- `process.command`: CLI command invocation (`"idocs"`).
- `process.executable.name`: Base executable name.
- `process.pid`: CLI process PID.
- `process.parent_pid`: Parent process PID.
- `process.exit.code`: Process exit code (`0` for success, non-zero for failure; guaranteed on root span).
- `process.command_args`: Sanitized CLI argument list (e.g. `["idocs", "search", "<argument>"]`).

#### Command Spans (`name = "idocs.command.<name>"`, `span.kind = "internal"`)
- `idocs.command.name`: One of `search`, `resolve`, `fetch`, `list`.
- `idocs.output.format`: Output serialization format (`text` or `json`).
- `idocs.caller.category`: Normalized caller type (`skill`, `mcp`, `benchmark`, `automation`, or `unknown`).
- `idocs.result.count`: Number of returned items.
- `idocs.source`: Primary result origin (`cache`, `local`, `apple`, `sosumi`, `help`, `mixed`, or `none`).

#### Dependency Spans (`span.kind = "client"`)
- HTTP spans (`name = "GET"`):
  - `http.request.method`: Uppercase method (`GET`).
  - `server.address`: Upstream host (e.g. `developer.apple.com`, `sosumi.ai`).
  - `server.port`: Non-default port if applicable.
  - `url.full`: Fully redacted URL containing only origin + `/<redacted>`.
  - `http.response.status_code`: HTTP response status code.
  - `http.request.resend_count`: Retry attempt count.
- Subprocess spans (`name = "mdfind"`):
  - `process.executable.name`: `"mdfind"`.
  - `process.pid`: Child process PID.
  - `process.exit.code`: Spotlight termination status.
  - `process.command_args`: Sanitized argument list.

#### Failure & Error Dimensions
- `error`: Boolean flag (`true` when failed).
- `error.type`: Low-cardinality machine error code (e.g. `not_found`, `invalid_argument`, `network_unavailable`, `upstream_rejected`, `_OTHER`).
- `error.category`: Normalized classification (`user`, `dependency`, `timeout`, `rate_limit`, `internal`).
- `error.expected`: Boolean indicating whether failure was normal domain behavior (e.g. user typo) vs abnormal system fault.
- `exception.slug`: Stable error slug (e.g. `idocs.command.fetch.failed`).

---

## 2. Honeycomb Golden Signals Query Library

### Query 1: Traffic & Invocation Volume by Command and Caller
Tracks invocation load, popular commands, and agent integration channels.

```json
{
  "calculations": [
    { "op": "COUNT" }
  ],
  "breakdowns": [
    "idocs.command.name",
    "idocs.caller.category"
  ],
  "filters": [
    { "column": "name", "op": "starts-with", "value": "idocs.command." }
  ],
  "time_range": 604800
}
```

### Query 2: Latency Distribution & High Percentiles
Visualizes execution duration heatmaps and latency percentiles (P50, P90, P95, P99).

```json
{
  "calculations": [
    { "op": "HEATMAP", "column": "duration_ms" },
    { "op": "P50", "column": "duration_ms" },
    { "op": "P90", "column": "duration_ms" },
    { "op": "P95", "column": "duration_ms" },
    { "op": "P99", "column": "duration_ms" }
  ],
  "breakdowns": [
    "idocs.command.name"
  ],
  "filters": [
    { "column": "name", "op": "starts-with", "value": "idocs.command." }
  ],
  "time_range": 604800
}
```

### Query 3: Error Rate & Unexpected Failures
Monitors unexpected failure spikes, isolating true service outages from expected client misses (`error.expected == false`).

```json
{
  "calculations": [
    { "op": "COUNT" },
    { "op": "COUNT_IF", "column": "error.expected", "value": false }
  ],
  "breakdowns": [
    "error.category",
    "error.type"
  ],
  "filters": [
    { "column": "error", "op": "=", "value": true }
  ],
  "time_range": 604800
}
```

### Query 4: External Upstream Network Performance (Apple CDN vs Sosumi)
Audits external dependency latency and HTTP status distribution.

```json
{
  "calculations": [
    { "op": "HEATMAP", "column": "duration_ms" },
    { "op": "P95", "column": "duration_ms" },
    { "op": "COUNT" }
  ],
  "breakdowns": [
    "server.address",
    "http.response.status_code"
  ],
  "filters": [
    { "column": "span.kind", "op": "=", "value": "client" },
    { "column": "server.address", "op": "exists" }
  ],
  "time_range": 604800
}
```

### Query 5: Subprocess Spotlight Index Health
Audits macOS local Spotlight latency and success rate.

```json
{
  "calculations": [
    { "op": "HEATMAP", "column": "duration_ms" },
    { "op": "P95", "column": "duration_ms" },
    { "op": "COUNT" }
  ],
  "breakdowns": [
    "process.exit.code"
  ],
  "filters": [
    { "column": "name", "op": "=", "value": "mdfind" }
  ],
  "time_range": 604800
}
```

---

## 3. Service Level Objectives (SLOs)

### SLO 1: Structured Documentation Resolve Reliability
- **Goal**: 99.0% over a 30-day rolling window.
- **Description**: Evaluates the reliability of `idocs resolve`, the primary agent-facing documentation retrieval tool.
- **SLI Formula**:
  $$\frac{\text{Count of spans where } \text{idocs.command.name} = \text{"resolve"} \text{ and } (\text{error} = \text{false} \text{ or } \text{error.expected} = \text{true})}{\text{Total count of } \text{idocs.command.name} = \text{"resolve"} \text{ spans}}$$
- **Burn Rate Triggers**:
  - Critical: Burn rate >= 14.4 (2% budget burn in 1 hour) -> Notify Slack / On-call.
  - Warning: Burn rate >= 6.0 (5% budget burn in 6 hours) -> Create investigation ticket.

### SLO 2: Interactive Execution Latency
- **Goal**: 95.0% of CLI invocations complete within 2,500 ms over a 30-day rolling window.
- **Description**: Ensures agents and engineers experience responsive tool execution.
- **SLI Formula**:
  $$\frac{\text{Count of root spans where } \text{duration\_ms} \le 2500}{\text{Total count of root spans}}$$

---

## 4. Honeycomb BubbleUp Triage Guide

When an error spike or latency regression occurs:

1. **Open the Query**: Run Query 2 (Latency) or Query 3 (Errors).
2. **Select Outliers with BubbleUp**:
   - In the Honeycomb Heatmap view, drag a selection box around the high-latency tail (> 3000ms) or failed executions.
3. **Inspect Differential Dimensions**:
   - `error.type` and `error.category`: Distinguish network drops (`network_unavailable`) from Apple CDN schema rejections (`upstream_rejected`).
   - `server.address`: Isolate whether Apple CDN (`developer.apple.com`) or Sosumi (`sosumi.ai`) is degrading.
   - `idocs.caller.category`: Determine if a specific caller (e.g. `benchmark` running massive parallel tasks) is dominating the spike.
   - `http.response.status_code`: Pinpoint HTTP 429 (rate limiting) or 503 (upstream outage).
4. **Inspect Trace Waterfall**:
   - Click a representative trace in the selected group to view exact HTTP attempt spans and child process timings.
