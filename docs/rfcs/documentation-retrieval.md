# Documentation retrieval and evidence

The CLI and application route documentation requests through the async [DocumentationService](../../Sources/iDocsAdapter/Protocols/DocumentationService.swift) boundary. The adapter owns configuration and maps Core models and errors into the public service contract. Core owns retrieval, caches, remote sources, and rendering. The adapter boundary lets CLI behavior be tested with an injected service and lets other clients supply their own cache directory and locking policy.

## Capability boundaries

| Capability | Responsibility |
| --- | --- |
| `resolve` | Resolve a complete structured Apple API intent. Build a canonical path, verify it with fetch, and use search candidates only when direct resolution fails or is ambiguous. |
| `fetch` | Retrieve authoritative evidence for a known canonical documentation path. |
| `search` | Discover and rank candidates for broad, natural-language, or imprecise queries. |
| `list` | Discover technology catalogs through explicit sources with stable result semantics. |

Commands are independent. In particular, users can pass the framework, symbol or type, optional member and member kind, source family, and caller context to a single resolve invocation. A high-confidence result requires fetch-backed evidence. Resolver attempts and fetch-source attempts have distinct diagnostics so consumers can distinguish a bad candidate from a retrieval failure.

Fetch prefers disk cache, then local Xcode documentation, then Apple and Sosumi. Search prefers its memory cache, then local Xcode documentation, then Apple and Sosumi. A usable hit terminates retrieval. A recoverable source error or miss allows the next eligible source to run. Search may skip broad Sosumi fallback for opaque misses that would produce unrelated results. Results carry provenance and the CLI distinguishes source misses, unsupported families, and upstream failures in its diagnostics.

The key regression checks are [resolver verification](../../Tests/iDocsTests/ResolveDocsToolTests.swift), [fetch and fallback](../../Tests/iDocsTests/FetchDocToolTests.swift), and the [adapter service contract](../../Tests/iDocsAdapterTests/DocumentationServiceContractTests.swift). The current CLI options and examples are in [Usage](../../README.md#usage).
