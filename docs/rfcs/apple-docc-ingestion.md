# Apple DocC ingestion and search

Apple's remote DocC payloads evolve independently of the models used by iDocs. [AppleDocCIngestion](../../Sources/iDocsKit/Rendering/AppleDocCIngestion.swift) confines that variability to the upstream boundary using a typed JSON representation. Renderers, adapters, callers, and disk cache continue to consume the normalized DocC model.

- Accept legacy string identifiers and Apple's object identifiers with a usable URL. If Apple omits the identifier field, derive one from the requested documentation path when available. Encode normalized identifiers as strings so they remain compatible with existing cache entries and callers.
- Preserve recognized content when optional sections, blocks, inline nodes, or references change shape. Report skipped nodes with their JSON paths. Recognize list item arrays, objects containing content arrays, and typed individual blocks.
- Select Apple when the response contains usable core evidence and renderable content. If required evidence is missing or the content is unusable, emit a path-aware decode failure and continue through the eligible fallback sources.
- Keep [remote transport](../../Sources/iDocsKit/DataSources/AppleDocumentationHTTPClient.swift) separate from [search traversal](../../Sources/iDocsKit/Search/AppleRemoteSearchCrawler.swift). Transport owns retries and their telemetry. Search ranks normalized candidates, deduplicates by path, excludes the generic technology breadcrumb, and bounds Apple remote results.

[Ingestion tests](../../Tests/iDocsTests/AppleDocCIngestionTests.swift) exercise stable encoding, tolerated schema changes, and invalid inputs. [Search relevance tests](../../Tests/iDocsTests/SearchRelevanceProfileTests.swift) cover ranking behavior.
