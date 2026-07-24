# iDocs OpenTelemetry v2 Design

## Summary

iDocs uses OpenTelemetry as a fail-open observability layer for its short-lived
CLI process. The v2 design covers the complete invocation lifecycle, explicit
exception logs, external HTTP and subprocess dependencies, and a privacy-safe
attribute contract.

The shared Cloudflare Worker is an OTLP gateway, not an iDocs application
component. Its implementation must remain service-neutral and route data by an
authenticated ingest profile. This repository defines the client and gateway
contracts; the Worker source and deployment belong in a separately versioned
infrastructure repository.

## Client Signals

iDocs emits:

- traces for CLI invocations, commands, meaningful pipelines, HTTP attempts,
  and subprocess calls;
- OTel log records for final unexpected exceptions;
- no application metrics in v2 because invocation counts, failure rate, and
  latency are queryable from wide root and command spans.

The gateway must accept all three standard OTLP/HTTP signals so that other
services can use metrics without changing the gateway protocol.

## CLI Lifecycle

The process entry point manually parses and executes `iDocsCLI` instead of
calling `AsyncParsableCommand.main`.

The lifecycle is:

1. Bootstrap tracing and logging.
2. Start the `idocs` root span.
3. Parse with `parseAsRoot` and run the selected command.
4. Preserve ArgumentParser presentation with `fullMessage(for:)` and
   `exitCode(for:)`.
5. Record the final exit code on the root span.
6. End the root span and perform a bounded flush and shutdown.
7. Exit the process only after telemetry shutdown completes.

Telemetry failures never change command output, stderr, or the process exit
code. Normal trace shutdown is bounded to 200 ms. Exception-log transport is
bounded to 100 ms, and exporter diagnostics are suppressed from the CLI
surface.

## Endpoint Contract

Default endpoints:

- traces:
  `https://telemetry-gateway.hamiltonsnow.workers.dev/v1/traces`
- logs:
  `https://telemetry-gateway.hamiltonsnow.workers.dev/v1/logs`

Resolution precedence is signal-specific endpoint, then
`OTEL_EXPORTER_OTLP_ENDPOINT` plus the standard signal path, then the default
gateway. `DISABLE_TELEMETRY=1` and `DO_NOT_TRACK=1` disable all signals.

The client sends OTLP/HTTP protobuf with gzip and never sends Honeycomb
credentials. Environment-derived `x-honeycomb-*` headers are intentionally
ignored by the exporters.

## Trace Model

### Resource

- `service.name = idocs`
- `service.namespace = com.snow`
- `service.version`
- `idocs.telemetry.schema.version = 2`
- deployment resource attributes supplied through the standard OTel resource
  environment

### CLI execution

- name: `idocs`
- kind: `INTERNAL`
- required attributes:
  - `process.executable.name`
  - `process.pid`
  - `process.exit.code`
- recommended attribute:
  - privacy-sanitized `process.command_args`
- failure attributes:
  - `error = true`
  - low-cardinality `error.type`

The executable, command, and option names may be retained. Positional values
and option values are replaced with fixed placeholders such as `<argument>`,
`<path>`, `<caller>`, `<value>`, or `<redacted>`.

### Commands

Command spans remain stable:

- `idocs.command.search`
- `idocs.command.resolve`
- `idocs.command.fetch`
- `idocs.command.list`

They contain low-cardinality command, output, result, source, caller-category,
and failure dimensions. Raw caller IDs are never emitted.

Pipeline spans remain compatibility boundaries in v2, but raw query and path
attributes have been removed. Stage details use events with low-cardinality
status and reason codes.

### HTTP dependencies

Every Apple, Apple Help, and Sosumi request attempt creates a `CLIENT` span:

- name: uppercase HTTP method, currently `GET`;
- `http.request.method`;
- `server.address` and non-default `server.port`;
- privacy-safe `url.full` containing only origin plus `/<redacted>`;
- `http.request.resend_count`;
- `http.response.status_code`;
- status `ERROR` and `error.type` for failed responses or transports.

Apple retries create one span per attempt. A failed attempt can remain an error
when a later retry or fallback makes the command successful.

### Subprocess dependencies

`SpotlightSearchProvider` creates an `mdfind` `CLIENT` span with:

- `process.executable.name`;
- sanitized `process.command_args`;
- child `process.pid`;
- `process.exit.code`;
- `timeout` or `subprocess_failed` classification when applicable.

The Spotlight expression and user query are never emitted.

## Exception Ownership

`TelemetryFailureDescriptor` is the stable error contract:

- `errorType`
- `category`
- `slug`
- `expected`
- `exceptionType`
- static `safeMessage`

Lower adapter, pipeline, HTTP, and subprocess spans use `markFailure`. The
command boundary owns the final result:

- expected failures such as invalid input and not-found mark the span but do
  not emit exception logs;
- a final unexpected failure calls `captureException` exactly once.

An exception log contains:

- `event.name = exception`
- `severity = ERROR`
- `exception.type`
- a static `exception.message`
- `exception.slug`
- `error.type`, `error.category`, and `error.expected`
- the active trace and span context

Stack traces, localized descriptions, associated error values, and legacy
`span.recordException` events are not emitted.

## Privacy Contract

The following fields are denied at the telemetry boundary:

- `idocs.query`
- `idocs.path`
- `idocs.query_attempt`
- `idocs.caller`
- `idocs.stage.reason`
- `idocs.category_filter`

Callers are reduced to `skill`, `mcp`, `benchmark`, `automation`, or `unknown`.
Reason codes must contain only lowercase ASCII letters, digits, `_`, `.`, or
`-` and be at most 64 characters; all other values become `other`.

Telemetry must never contain raw paths, user queries, personal identifiers,
tokens, arbitrary diagnostic text, localized exception messages, or response
bodies.

## Shared Gateway Contract

The normative onboarding and compatibility contract for all current and
future clients is
[OpenTelemetry Gateway Client Integration Standard](../telemetry/otel-gateway-client-standard.md).
This section records the architecture decision; the integration standard is
the operational source of truth.

The gateway supports:

- `POST /v1/traces`
- `POST /v1/logs`
- `POST /v1/metrics`
- `GET /healthz`

OTLP request and response bodies are streamed without protobuf decoding or
business-specific rewriting. Only `application/x-protobuf` with identity or
gzip encoding is accepted.

The gateway resolves an `IngestProfile` from the hostname and authenticated
principal:

```text
IngestProfile
- profileID
- audience: public | internal
- honeycombEnvironment
- apiKeyBinding
- allowedSignals
- authenticationPolicy
- rateLimitPolicy
- maxBodyBytes
```

Gateway rules:

- strip client `authorization`, `cookie`, `cf-access-*`, and
  `x-honeycomb-*` headers;
- inject only the profile's environment-scoped Honeycomb ingest key;
- never accept a client-selected upstream key or environment;
- stream payloads and reject oversized requests;
- do not retry upstream writes;
- preserve successful OTLP response bodies;
- return sanitized errors while preserving status and `Retry-After`;
- log only profile, signal, status, duration, payload-size bucket, rate-limit
  outcome, and deployment version.

The existing hostname is the unauthenticated `public-idocs` profile and must
use an isolated Honeycomb environment. Internal services share a separate
Cloudflare Access-protected hostname. Another public binary requires its own
hostname, profile, rate limit, and Honeycomb environment.

## Verification

Automated client gates cover:

- endpoint precedence and opt-out;
- root and command parentage;
- final exit codes and ArgumentParser presentation;
- one trace-correlated exception log per unexpected failure;
- no log for expected failures;
- absence of legacy exception span events;
- HTTP and subprocess semantic attributes;
- absence of denied privacy fields;
- exporter timeout and fail-open behavior.

Gateway staging must be validated with both `idocs` and a non-iDocs canary
before production deployment. Honeycomb acceptance queries must verify root
latency distributions, error grouping, exception-to-trace correlation,
dependency latency, privacy-field absence, and profile isolation.

Production Worker deployment, secret changes, and Access policy changes are
separate high-risk operations and require explicit deployment approval.
