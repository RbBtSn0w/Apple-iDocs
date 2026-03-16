# Feature Specification: Three-Layer Architecture Refactoring

**Feature Branch**: `005-three-layer-architecture`  
**Created**: 2026-03-16  
**Status**: Draft  
**Input**: 系统必须采用三层架构（应用层/公共层/适配层）：CLI、App 分别作为应用层入口；公共层仅包含核心能力且不依赖任何接入方式；适配层 以协议+实现方式将不同应用层与公共层对接，从而实现接入方式与核心能力的解耦与可复用。当前主要选用 CLI 方式提供服务，未来支持 App 的 UI 交互方式提供入口查询能力。

## Clarifications
### Session 2026-03-16
- Q: How should the system handle potential file-system or cache contention between multiple application processes (e.g., multiple CLI instances or App + CLI)? → A: Not required by default. CLI and App do not share the same cache directory (App sandbox isolation). If a shared cache is introduced later, file-based locking (e.g., flock) should be considered.
- Q: Authentication and Session Management → A: Application Layer (CLI or App).
- Q: Definition of "App" Entry Point → A: Native Apple Platforms (macOS, iOS, iPadOS).
- Q: How should the iDocsKit (Common) and Adapter layers be delivered to the Application layers? → A: Common layer supports framework/xcframework delivery; CLI may statically or dynamically link.
- Q: Where should the responsibility for localization (L10n) and internationalization (I18n) reside? → A: Mixed: Common layer supports language parameters (e.g., locale); Application layers provide their own UI strings.
- Q: How should application-specific configuration be passed to the Common/Adapter layers? → A: Injected Configuration Object: Pass a Configuration instance during initialization.
- Q: How should the Common layer handle logging to ensure it's observable by all Application layers? → A: Dependency Injection (Logger Protocol): Inject a platform-specific Logger implementation.
- Q: Should the Adapter layer's primary interface be exclusively async/await? → A: Pure async/await: Use modern Swift concurrency for all Adapter methods.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unified CLI Access (Priority: P1)

As a developer, I want to use the iDocs CLI to search and fetch documentation, ensuring that the CLI only acts as a thin wrapper around a stable core service.

**Why this priority**: The CLI is the primary interaction tool. Establishing a thin CLI layer proves the core decoupling.

**Independent Test**: Can be tested by running the `iDocs` command. Success is measured by the CLI correctly invoking the underlying `iDocsKit` via an adapter without direct tool instantiation.

**Acceptance Scenarios**:

1. **Given** a clean build, **When** I run `iDocs search "SwiftUI"`, **Then** the CLI should delegate the request to the Adapter layer.
2. **Given** a network failure, **When** the core layer throws an error, **Then** the CLI should receive a standardized error from the adapter and display it to the user.

---

### User Story 2 - Future App Integration Readiness (Priority: P1)

As a product owner, I want to ensure the system is architected to allow a native App UI to be built using the exact same core logic as the CLI.

**Why this priority**: Future-proofing the architecture to avoid rework when building the UI client.

**Independent Test**: Can be verified by creating a minimal SwiftUI-based test target that uses the same Adapter protocol as the CLI to fetch a document title.

**Acceptance Scenarios**:

1. **Given** the Adapter protocol is implemented, **When** a SwiftUI view calls the search method, **Then** it should return the same results as the CLI.
2. **Given** a shared cache, **When** the CLI fetches a document, **Then** the App UI should be able to retrieve it from the cache instantly without re-downloading.

---

### User Story 3 - Mock Adapter for Isolated Testing (Priority: P2)

As a maintainer, I want to be able to swap the real Common layer with a Mock implementation at the Adapter level to test Application layers in isolation.

**Why this priority**: Essential for long-term maintainability and CI/CD stability, avoiding external dependency on Apple documentation servers during tests.

**Independent Test**: Can be tested by running unit tests for the CLI using a Mock Adapter that returns predefined documentation data.

**Acceptance Scenarios**:

1. **Given** a test environment, **When** the CLI is initialized with a `MockDocumentationAdapter`, **Then** it should return mock data without making any real network or disk calls.

---

### Edge Cases

- **Version Mismatch**: What happens if the Common layer is updated but the Adapter implementation for an entry point is not?
- **Resource Contention (Scoped)**: CLI and App do not share the same cache directory under current sandbox rules. If a shared cache is introduced later, file-based locking (flock) should be used.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: **Common Layer (iDocsKit)** MUST contain all core documentation fetching, rendering, and caching logic without any dependency on CLI-specific frameworks (like ArgumentParser). It MUST support language parameters to enable fetching localized documentation.
- **FR-002**: **Adapter Layer** MUST define a set of protocols (e.g., `DocumentationService`) that abstract the capabilities of the Common layer, including support for locale/language context.
- **FR-003**: **Common Layer (iDocsKit)** MUST expose configuration and logger injection points to allow Application layers to pass environment-specific settings.
- **FR-004**: **Application Layer (CLI)** MUST be refactored to use the Adapter protocols instead of directly instantiating Tools or Fetchers. It MUST use `AsyncParsableCommand` to support the pure `async/await` interface of the Adapter. It MUST inject an environment-specific **Configuration object** and a **Logger implementation** into the Adapter during initialization.
- **FR-005**: The system MUST support a `MockDocumentationAdapter` or `InMemoryAdapter` for testing purposes.
- **FR-006**: **Authentication and Session Management** MUST be handled by the **Application Layer** (CLI or App). The Adapter and Common layers should remain stateless regarding user identity.
- **FR-007**: The **Common Layer (iDocsKit)** MUST support delivery as a **.framework or .xcframework** for App targets. The CLI MAY link the Common layer statically or dynamically. The Adapter layer MUST exclusively use **Pure async/await** (Swift Concurrency).
- **FR-008**: **Common Layer (iDocsKit)** SHOULD implement file-based locking only if a shared cache directory is introduced across processes.
- **FR-009**: **Common Layer (iDocsKit)** MUST define a **Logger protocol** to allow Application layers to receive internal logs without coupling the core to a specific logging framework.
- **FR-010**: **Adapter Layer** MUST provide a stable, developer-friendly API surface (clear naming, structured errors like `DocumentationError`, and predictable result types) to balance decoupling rigor with developer experience.
- **FR-011**: **Common Layer (iDocsKit)** MUST provide an explicit `Configuration` type containing, at minimum: cache path, API endpoint base URL, locale, and timeout settings. Application layers MUST inject this configuration through the Adapter.
- **FR-012**: **Adapter Layer** MUST support App sandbox constraints (e.g., cache path injection and avoiding global writable locations by default).
- **FR-013**: **Adapter Layer** MUST document and enforce version compatibility between Adapter and Common layers (e.g., SemVer alignment or runtime version checks).
- **FR-014**: **Version Compatibility** MUST be enforced at runtime via a simple version handshake (Adapter reads Common layer version and fails fast with a clear error if the major versions are incompatible).

### Key Entities

- **DocumentationService (Protocol)**: The primary interface in the Adapter layer defining search, fetch, and list capabilities.
- **Adapter Implementation**: Concrete classes that bridge `iDocsKit` (Common) to the `DocumentationService` protocol.
- **Application Context**: A shared configuration or state passed from Application layers to the Common layer via the Adapter.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **100% Decoupling**: The `iDocsKit` target must not have a dependency on `ArgumentParser`.
- **SC-002**: **Zero Logic Duplication**: Search and Fetch logic must only exist once in the Common layer and be reused by all Application layers.
- **SC-003**: **Testability**: Unit tests for the Application layer (CLI) must be able to pass using only Mocks/Adapters without needing a real documentation cache.
- **SC-004**: **Extensibility**: Adding a new Application layer (e.g., "macOS App") should only require implementing a new UI/Entry point and using the existing Adapter, without modifying the Common layer.
- **SC-005 (Gate)**: **Target Dependency Gate**: `iDocsKit` MUST NOT depend on Application or Adapter targets; CI must fail if this dependency appears.
- **SC-006 (Gate)**: **Access Gate**: CLI/App code MUST NOT directly instantiate Common-layer Tools or Fetchers; all access goes through Adapter protocols.
- **SC-007 (Gate)**: **Concurrency Gate**: Adapter APIs are async-only (no completion-handler overloads).
- **SC-008 (Gate)**: **App Readiness Gate**: Adapter + Common must run in App sandbox with an injected cache path and no writes to global directories by default.
- **SC-009 (Gate)**: **Version Gate**: Adapter must verify the Common layer major version at startup and emit a clear error if incompatible.
