# OpenTelemetry Gateway Client Integration Standard

Status: Proposed normative standard

Version: 1.0

Last updated: 2026-07-24

## 1. Purpose

This document defines the contract for applications, services, CLIs, agents,
and SDKs that export OpenTelemetry data through the shared telemetry gateway.
It is the onboarding authority for new clients.

This standard deliberately keeps the gateway independent of iDocs and any
other individual business schema. A client that follows this contract can be
added without changing the gateway's OTLP payload handling.

Normative terms such as **MUST**, **MUST NOT**, **SHOULD**, and **MAY** are to
be interpreted as requirements for compatibility.

## 2. Integration Model

```text
OTel client
  -> approved gateway hostname
  -> authentication and IngestProfile resolution
  -> request validation and rate limiting
  -> Honeycomb OTLP ingest endpoint
```

The gateway owns upstream credentials, environment routing, request limits,
and admission policy. The client owns instrumentation quality, resource
identity, privacy-safe attributes, bounded export, and fail-open behavior.

The gateway is not a telemetry SDK, Collector processor, or business-schema
translator. It does not repair malformed spans, decode business attributes, or
select a Honeycomb environment from client input.

## 3. Prerequisites

Before implementation, the client owner MUST obtain an approved
`IngestProfile` from the gateway operator:

| Field | Meaning |
|---|---|
| `profileID` | Stable, low-cardinality gateway profile identifier |
| `gatewayBaseURL` | Approved hostname and optional base path |
| `audience` | `public` or `internal` |
| `allowedSignals` | Any subset of `traces`, `logs`, and `metrics` |
| `authenticationPolicy` | Public profile or the required internal identity mechanism |
| `rateLimitPolicy` | Sustained and burst request limits |
| `maxBodyBytes` | Maximum compressed request size accepted by the profile |
| `honeycombEnvironment` | Operator-owned destination; informational to the client |

A client MUST NOT reuse another product's public hostname merely because it is
reachable. Each public distributable requires its own hostname, profile,
rate-limit policy, credential binding, and isolated Honeycomb environment.
Internal services MAY share an internal hostname only when the operator has
approved profile resolution and tenant isolation for those identities.

## 4. OTLP Transport Contract

### 4.1 Endpoints

The gateway exposes standard OTLP/HTTP endpoints:

| Signal | Method and path | Required content type |
|---|---|---|
| Traces | `POST /v1/traces` | `application/x-protobuf` |
| Logs | `POST /v1/logs` | `application/x-protobuf` |
| Metrics | `POST /v1/metrics` | `application/x-protobuf` |
| Health | `GET /healthz` | N/A |

Only signals listed in the client's `allowedSignals` may be sent. OTLP/gRPC,
OTLP/HTTP JSON, arbitrary paths, and browser beacon formats are outside this
contract unless a later standard explicitly adds them.

Clients MAY send an identity-encoded protobuf body or gzip-compressed protobuf
with:

```http
Content-Type: application/x-protobuf
Content-Encoding: gzip
```

Clients MUST NOT assume that a successful response has an empty body. They
MUST decode the signal-specific OTLP response, including partial-success
fields. A partial-success response MUST NOT be retried. Every non-2xx response
is a failed export.

### 4.2 Endpoint Configuration

Clients SHOULD use the standard OpenTelemetry environment variables:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otel.example.com"
```

An SDK using this base endpoint appends `/v1/traces`, `/v1/logs`, or
`/v1/metrics` according to the signal.

Signal-specific overrides MAY be used:

```bash
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://otel.example.com/v1/traces"
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="https://otel.example.com/v1/logs"
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT="https://otel.example.com/v1/metrics"
```

Signal-specific values are complete URLs and MUST NOT have another OTLP path
appended. Endpoint precedence is:

1. signal-specific endpoint;
2. base OTLP endpoint plus the standard signal path;
3. an application-owned, documented default.

The endpoint MUST use HTTPS outside isolated local tests.

### 4.3 Headers and Credentials

Clients MUST NOT send any Honeycomb API key or select an upstream Honeycomb
environment. In particular, clients MUST NOT send:

```text
x-honeycomb-team
x-honeycomb-dataset
authorization containing an upstream ingest key
cookie
cf-access-* copied from an interactive browser session
```

The gateway removes untrusted routing and credential headers, then injects the
environment-scoped upstream credential bound to the resolved `IngestProfile`.

Internal profiles use the non-interactive workload identity or Cloudflare
Access service-token mechanism specified by the gateway operator. Such
credentials MUST come from a secret store, MUST NOT be represented as
telemetry attributes, and MUST NOT be compiled into distributable binaries.

Public profiles do not embed a secret. Their isolation depends on a dedicated
profile, environment, body-size limit, and rate-limit policy.

## 5. Required Client Telemetry Contract

### 5.1 Resource Identity

Every exported signal MUST include:

| Attribute | Requirement | Example |
|---|---|---|
| `service.name` | Required; stable product or service identifier | `idocs` |
| `service.version` | Required for released artifacts | `1.4.0` |
| `service.namespace` | Required when names may collide | `com.example` |
| `deployment.environment.name` | Recommended for hosted workloads | `production` |
| `telemetry.sdk.*` | SDK-generated; MUST NOT be overwritten | SDK-defined |

`service.name` MUST NOT include a hostname, process ID, customer, user, build
path, or other high-cardinality value. Separate logical services use separate
names; replicas of the same service do not.

### 5.2 Span Design

Clients MUST:

- create one root span for each independently meaningful operation;
- propagate W3C Trace Context across supported process and network boundaries;
- use `SpanKind.CLIENT` for outbound HTTP, RPC, database, and subprocess calls;
- use low-cardinality span names;
- record required semantic-convention attributes for the instrumented domain;
- record the final operation or process result before ending the root span.

For CLI programs and subprocesses:

- CLI-owned execution uses `SpanKind.INTERNAL`;
- subprocess calls use `SpanKind.CLIENT`;
- span names default to `process.executable.name`;
- `process.executable.name`, `process.pid`, and `process.exit.code` are
  recorded where required by the applicable semantic convention;
- a non-zero exit records a low-cardinality `error.type`.

For HTTP clients:

- use a low-cardinality method or route-based span name;
- record `http.request.method`, `server.address`, and
  `http.response.status_code` when available;
- remove user information, query strings, fragments, tokens, and raw document
  paths from URL attributes.

### 5.3 Error and Exception Ownership

Every failed operation span MUST set:

```text
error.type       low-cardinality failure class
error.category   user | dependency | timeout | rate_limit | internal
error.expected   true | false
```

Expected failures such as invalid input or a normal not-found result SHOULD be
represented on the span and SHOULD NOT generate an exception log.

An unexpected final failure SHOULD generate exactly one exception log at the
operation boundary that owns the failure. Lower layers mark their spans and
rethrow; they MUST NOT each emit duplicate exception logs.

Exception logs MUST be trace-correlated and contain only:

```text
exception.type
exception.message   sanitized, stable message
exception.slug      stable grouping identifier
error.type
error.category
error.expected
```

Raw localized errors, stack traces containing paths or arguments, response
bodies, and recursively serialized error objects MUST NOT be exported by
default.

### 5.4 Privacy and Cardinality

Telemetry MUST NOT contain:

- raw file-system paths or home-directory names;
- user search queries, prompts, document contents, or response bodies;
- email addresses, account identifiers, or arbitrary caller identities;
- access tokens, API keys, cookies, authorization headers, or signed URLs;
- arbitrary error text or unbounded command arguments;
- dynamic values in metric names, span names, or attribute keys.

Clients SHOULD convert sensitive values into bounded classifications, for
example:

```text
caller category: skill | mcp | benchmark | automation | unknown
result source: local | cache | apple | fallback
reason code: not_found | timeout | invalid_response | other
```

Hashing a sensitive or user-controlled value does not automatically make it
acceptable: stable hashes can remain identifiers and preserve high
cardinality. Use an allowlisted category unless an approved use case requires
otherwise.

## 6. Exporter Reliability Requirements

Telemetry MUST be fail-open: export failure, gateway rejection, timeout, or
rate limiting MUST NOT change the business result.

Each client MUST define:

- bounded connect and request timeouts;
- bounded queue and batch sizes;
- a memory limit appropriate for the process lifetime;
- explicit shutdown or flush behavior;
- sampling policy and its owner;
- opt-out behavior where required for distributable software.

Short-lived processes MUST flush after finalizing the root operation and
before process termination. The flush budget MUST be finite. Clients SHOULD
avoid unbounded retries; they MUST NOT retry non-retryable 4xx responses.
Retry behavior for `429` or transient 5xx responses must honor `Retry-After`,
remain within the process budget, and avoid multiplying retries already
performed by the SDK or gateway.

The gateway does not retry upstream ingest requests. This avoids duplicate
telemetry and keeps backpressure visible to clients and operators.

## 7. Response Handling

Clients MUST use the following interpretation:

| Response | Client behavior |
|---|---|
| `2xx` | Export accepted; process any OTLP response body |
| `400` | Do not retry unchanged payload; fix encoding or schema |
| `401` / `403` | Do not retry continuously; verify profile identity and authorization |
| `404` / `405` | Verify signal path and HTTP transport |
| `413` | Reduce batch/body size below the profile limit |
| `415` | Use OTLP protobuf and supported content encoding |
| `429` | Apply bounded backoff and honor `Retry-After` |
| `502`, `503`, `504` | Retry with jittered exponential backoff within the bounded budget |
| Other `5xx` | Do not automatically retry unless a later OTLP standard classifies it as retryable |

Gateway error bodies are diagnostic hints, not a stable parsing API. Client
behavior MUST be based on HTTP status and standard headers.

## 8. Client Onboarding Procedure

### Step 1: Define identity and signals

Provide the gateway operator with:

- owning team and operational contact;
- `service.name`, namespace, and deployment environments;
- public or internal audience;
- required signals;
- expected request rate and maximum batch size;
- data classification and retention expectations.

### Step 2: Receive an IngestProfile

Confirm the assigned hostname, authentication policy, allowed signals,
rate/body limits, and isolated Honeycomb destination. Do not implement against
another product's profile as a temporary shortcut.

### Step 3: Configure the SDK

Use the official OTel SDK or Collector distribution for the client language.
Configure OTLP/HTTP protobuf, resource identity, timeouts, batching, and the
approved gateway endpoint. Keep credentials in the platform secret store.

Example environment-only configuration:

```bash
export OTEL_SERVICE_NAME="example-worker"
export OTEL_RESOURCE_ATTRIBUTES="service.namespace=com.example,deployment.environment.name=staging"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otel-staging.example.com"
```

Authentication headers, when required, are supplied using the secure
mechanism approved for that profile. They should not be committed to shell
scripts, source files, fixtures, or documentation examples.

### Step 4: Validate locally

Before sending data externally, use an in-memory exporter or local Collector
to verify:

- root/child parentage and W3C context propagation;
- success and failure statuses;
- exception-to-trace correlation;
- dependency span kinds and semantic attributes;
- bounded resource attributes and span names;
- absence of forbidden fields;
- application success when the exporter is offline.

### Step 5: Validate in gateway staging

Send four canary cases:

1. successful operation;
2. expected failure without an exception log;
3. unexpected failure with exactly one correlated exception log;
4. gateway unavailable or rate-limited while the application still completes
   according to its business contract.

The client and gateway owners then verify in Honeycomb:

- data arrives only in the assigned environment;
- `service.name` and version are correct;
- traces are complete and exception logs link to their trace;
- no raw paths, queries, identities, secrets, or response bodies appear;
- gateway status, latency, and rate-limit outcomes match the canary;
- another profile cannot write into or query-select this environment.

### Step 6: Production approval

Production profile creation, Worker deployment, route changes, Access policy
changes, secret rotation, and upstream key changes are separate controlled
operations. They require the gateway owner's approval and rollback plan.

## 9. Acceptance Checklist

A new client is compatible only when every item is satisfied:

- [ ] An owner and approved `IngestProfile` exist.
- [ ] The client uses OTLP/HTTP protobuf on an allowed signal path.
- [ ] The client does not carry a Honeycomb ingest credential.
- [ ] Resource identity is stable and low-cardinality.
- [ ] Root, dependency, error, and exception ownership contracts are tested.
- [ ] Telemetry passes the privacy denylist review.
- [ ] Export queues, timeouts, flush, and retry behavior are bounded.
- [ ] Export failure does not affect the business result.
- [ ] Staging canaries pass for success, expected failure, unexpected failure,
      and gateway failure.
- [ ] Honeycomb profile isolation and data routing are verified.
- [ ] Operational owner, dashboard/SLO expectations, and rollback path are
      documented.

## 10. Troubleshooting

| Symptom | First checks |
|---|---|
| No telemetry | Opt-out flags, endpoint precedence, allowed signal, SDK protocol |
| `401` or `403` | Approved hostname, workload identity, profile authorization |
| `404` | `/v1/traces`, `/v1/logs`, or `/v1/metrics` path |
| `413` | Exporter batch size and compressed request size |
| `415` | `application/x-protobuf` and supported content encoding |
| Frequent `429` | Batch frequency, profile rate limit, `Retry-After` handling |
| Trace fragments | Parent context propagation and premature process exit |
| Missing exception links | Log SDK context propagation and final error owner |
| High Honeycomb cardinality | Span names, resource identity, raw/user-controlled attributes |
| Business latency regression | Synchronous export, excessive flush budget, exporter retries |

Gateway operators should diagnose gateway health by profile, signal, response
status, duration, payload-size bucket, rate-limit outcome, and deployment
version. Gateway logs MUST NOT include OTLP payloads or sensitive request
headers.

## 11. Compatibility and Change Management

The gateway contract is compatible across businesses because routing and
authorization use the hostname and authenticated principal, not business
attributes inside the OTLP payload.

Additive support for a new signal, optional header, or diagnostic field is a
minor change. Removing a signal, changing authentication, lowering limits
below observed production usage, changing endpoint semantics, or requiring a
new resource field is a breaking change and requires:

1. a new standard version;
2. an announced migration window;
3. staging compatibility tests;
4. per-profile rollout and rollback;
5. explicit client-owner acknowledgement.

Business-specific telemetry conventions belong in the client's own schema
documentation. They MUST NOT be enforced by decoding or rewriting payloads in
the shared gateway.

## 12. Normative References

- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)
- [OTLP Exporter Configuration Specification](https://opentelemetry.io/docs/specs/otel/protocol/exporter/)
- [OTLP SDK Environment Configuration](https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/)
- [Resource Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/resource/)
- [Deployment Attributes](https://opentelemetry.io/docs/specs/semconv/registry/attributes/deployment/)
- [CLI Span Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/cli/cli-spans/)
