# Research: Tuist 4+ Migration Patterns

## Decision: Use Centralized Manifests (Tuist 4 Style)

**Rationale**: 
Tuist 4 introduced a more streamlined way to manage dependencies and project structure. By using `Tuist/Package.swift` for SPM dependencies and `Project.swift` for target definitions, we follow the latest best practices which provide better caching, faster project generation, and a cleaner project root.

**Alternatives Considered**:
- **Keeping Root `Package.swift`**: This leads to redundancy and potential synchronization issues between Tuist and SPM. Tuist's `.external` dependencies are the preferred way to bridge SPM into a Tuist project.
- **Tuist 3 Style (Dependencies.swift)**: Deprecated in favor of the more robust `Tuist/Package.swift` approach which leverages the actual `PackageDescription` framework from SPM.

## Findings

### 1. Dependency Mapping
The current `Package.swift` dependencies will be mapped to `Tuist/Package.swift` as follows:

| SPM Package | Tuist Reference |
|-------------|-----------------|
| `swift-sdk` | `.external(name: "MCP")` |
| `swift-service-lifecycle` | `.external(name: "ServiceLifecycle")` |
| `swift-log` | `.external(name: "Logging")` |

### 2. Project Structure
The `Project.swift` needs to be updated to:
- Define the `iDocs` executable target.
- Define the `iDocsTests` unit test target.
- Point to `Sources/iDocs` and `Tests/iDocsTests`.
- Set macOS 13.0+ as the deployment target.

### 3. Migration Workflow
1.  **Preparation**: Back up `Package.swift`.
2.  **Configuration**: Create/Update `Tuist/Package.swift` with dependencies.
3.  **Project Manifest**: Update `Project.swift` to use `.external` dependencies.
4.  **Verification**: 
    - `tuist install` to resolve dependencies.
    - `tuist generate` to create the workspace.
    - `tuist build` to verify the executable.
    - `tuist test` to verify the unit tests.
5.  **Cleanup**: Remove or rename the root `Package.swift` to avoid confusion.

## Unknowns Resolved
- **Q: How does Tuist handle SPM products with different names than the package?**
  - **A**: Tuist 4's `Package.swift` integration handles this automatically. We reference them by the product name defined in the package, which is exactly what `.external(name:)` expects.
- **Q: Will `swift test` still work?**
  - **A**: `swift test` requires a `Package.swift`. After migration, we should use `tuist test` for consistency. If `swift test` is still needed (e.g., for CI tools that only support SPM), we can keep a stub `Package.swift` or generate one, but `tuist test` is the primary command.
