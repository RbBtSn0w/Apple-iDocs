# iDocs OpenTelemetry Gateway Conformance

Status: Implemented client contract

Gateway contract: `otel-gateway-client/v2`

Last updated: 2026-07-24

The shared platform contract is owned by the OTel Gateway. This document
records only the iDocs-specific conformance choices.

## Assigned admission

```yaml
serviceName: idocs
serviceNamespace: com.snow
trustClass: anonymous
profileID: anonymous-client-v1
allowedSignals: [traces]
gatewayBaseURL: https://telemetry-gateway.hamiltonsnow.workers.dev
approvedGatewayOrigins:
  - https://telemetry-gateway-development.hamiltonsnow.workers.dev
  - https://telemetry-gateway-staging.hamiltonsnow.workers.dev
  - https://telemetry-gateway.hamiltonsnow.workers.dev
```

Requests to the approved gateway carry:

```http
otel-gateway-profile: anonymous-client-v1
```

The header is admission metadata, not authentication or backend routing.
Only one of the exact approved HTTPS origins on effective port 443 receives it; HTTP,
non-default ports, and custom Collector endpoints do not inherit it.

## Client responsibilities

iDocs owns:

- stable Resource identity and low-cardinality span names;
- CLI, command, HTTP, and subprocess span semantics;
- sanitizer and privacy denylist behavior;
- bounded queues, timeouts, flush, opt-out, and fail-open behavior;
- final error fields on the owning span.

iDocs exports OTLP/HTTP protobuf traces with gzip. It does not export OTel
Logs or metrics and does not accept ambient OTLP credential headers.

As distributable software, iDocs does not claim a hosted
`deployment.environment.name`. Gateway destinations are operator-owned and
are not selected from Resource attributes.

## Gateway boundary

The gateway validates method, path, profile, content type, content encoding,
declared length, and rate policy. It strips untrusted credentials, injects the
destination adapter credential, and streams the protobuf body once.

The gateway never parses, decompresses, sanitizes, repairs, or rewrites iDocs
telemetry. Privacy defects must be fixed and tested in iDocs.

## Verification

Before a deployed canary:

- verify Root/Child parentage and CLI semantic conventions in memory;
- verify no query, path, document content, identity, token, response body,
  exception message, stack trace, or arbitrary diagnostic text is exported;
- verify only the exact approved HTTPS origin receives the profile;
- verify exporter failure does not change CLI output or exit behavior.

After an operator deploys the v2 gateway, run a real low-risk iDocs operation
and use the backend MCP to prove the dataset, Resource, span tree, error
fields, and absence of forbidden attributes. Deployment, route, Secret,
Board, and Trigger changes require separate authorization.
