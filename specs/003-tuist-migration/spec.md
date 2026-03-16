# Feature Specification: Migrate project management to Tuist

**Feature Branch**: `003-tuist-migration`  
**Created**: 2026-03-16  
**Status**: Completed  
**Input**: User description: "将项目的管理完整的迁移到tuist的管理模式上。"

## Clarifications

### Session 2026-03-16
- Q: Which legacy artifacts should be removed? → A: Remove root Package.swift, .swiftpm/ directory, and root .xcodeproj/.xcworkspace.
- Q: Should CI/CD pipelines use Tuist? → A: Update all CI workflows to use tuist build and tuist test.
- Q: Should binary caching be enabled? → A: Enable binary caching for all external SPM dependencies.
- Q: Should Tuist version be pinned? → A: Pin Tuist version using a .tuist-version file in the project root.
- Q: Should targets use shared configuration? → A: Implement a shared Settings object for all targets to enforce consistency.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer Setup and Project Generation (Priority: P1)

As a developer, I want to generate the entire Xcode workspace using a single Tuist command so that I can start development without manually configuring Xcode settings.

**Why this priority**: Essential for the core developer workflow and project maintainability.

**Independent Test**: Running `tuist install` followed by `tuist generate` creates a functional Xcode workspace with all dependencies linked correctly.

**Acceptance Scenarios**:

1. **Given** a fresh clone of the repository, **When** I run `tuist install && tuist generate`, **Then** an `iDocs.xcworkspace` is created.
2. **Given** the generated workspace, **When** I open it in Xcode, **Then** all targets (iDocs, iDocsTests) are present and dependencies are resolved.

---

### User Story 2 - Building and Testing via Tuist CLI (Priority: P2)

As a CI/CD pipeline or developer, I want to build and test the project using the Tuist CLI so that I have a consistent environment across local and remote builds.

**Why this priority**: Ensures build consistency and leverages Tuist's caching and optimization features.

**Independent Test**: Running `tuist build` and `tuist test` completes successfully without manual Xcode intervention.

**Acceptance Scenarios**:

1. **Given** the project is generated, **When** I run `tuist build`, **Then** the `iDocs` executable is successfully compiled.
2. **Given** the project is generated, **When** I run `tuist test`, **Then** all unit tests in `iDocsTests` are executed and pass.

---

### User Story 3 - Dependency Management via Tuist (Priority: P2)

As a developer, I want to manage project dependencies using Tuist's integrated SPM support so that all dependencies are centralized and correctly integrated into the generated project.

**Why this priority**: Simplifies dependency management and ensures alignment between Tuist and SPM.

**Independent Test**: Adding a new dependency in `Tuist/Package.swift` and running `tuist install` correctly integrates it into the project.

**Acceptance Scenarios**:

1. **Given** a new dependency is added to `Tuist/Package.swift`, **When** I run `tuist install && tuist generate`, **Then** the new library is available for import in the project targets.

---

### Edge Cases

- **Broken Dependencies**: How does the system handle an invalid `Tuist/Package.swift`? (Tuist CLI should provide clear error messages).
- **Migration Conflict**: What happens if both `Package.swift` and `Tuist/Package.swift` exist? (The migration should clearly define which one is the source of truth, typically `Tuist/Package.swift`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST use Tuist 4+ management style (centralized manifests).
- **FR-002**: All external dependencies MUST be moved from root `Package.swift` to `Tuist/Package.swift`.
- **FR-003**: Legacy project artifacts (root `Package.swift`, `.swiftpm/` directory, and root `.xcodeproj`/`.xcworkspace`) MUST be removed to ensure a clean repository structure.
- **FR-004**: Project MUST be fully manageable and buildable solely through Tuist manifests and CLI.
- **FR-005**: Project MUST be defined in `Project.swift` with all targets, destinations, and settings.
- **FR-006**: System MUST support project generation, building, and testing via Tuist CLI.
- **FR-007**: All CI/CD workflows (e.g., GitHub Actions) MUST be updated to use `tuist build` and `tuist test`.
- **FR-008**: Build settings and deployment targets MUST be standardized across all targets via Tuist.
- **FR-009**: Binary caching MUST be enabled for all external SPM dependencies to optimize build performance.
- **FR-010**: The project MUST pin the Tuist version using a `.tuist-version` file to ensure build reproducibility across all environments.
- **FR-011**: All project targets MUST share a unified `Settings` object to enforce consistent build configurations and macOS versions.

### Key Entities *(include if data involved)*

- **Tuist Manifests**: Swift files (`Project.swift`, `Tuist/Package.swift`, `Tuist/Config.swift`) that define the project structure and dependencies.
- **Project Targets**: The executable (`iDocs`) and test bundle (`iDocsTests`) defined in the manifests.
- **Dependencies**: External libraries managed via SPM and integrated into targets via Tuist.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Project generation via `tuist generate` completes in under 10 seconds (excluding dependency fetching).
- **SC-002**: 100% of targets build successfully using `tuist build`.
- **SC-003**: 100% of tests pass when executed via `tuist test`.
- **SC-004**: Zero manual Xcode configuration required after project generation to run the application.
