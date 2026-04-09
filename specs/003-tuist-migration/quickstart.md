# Quickstart: Working with the Tuist-Managed iDocs Project

## Prerequisites
- **Tuist 4.158.2**: The version is pinned via `.tuist-version`. Install via `curl -Ls https://install.tuist.io | bash`.
- **Xcode 15.0+**: Required for Swift 6 support.

## Initial Setup
1. Clone the repository.
2. Resolve and install SPM dependencies:
   ```bash
   tuist install
   ```
3. Generate the project:
   ```bash
   tuist generate
   ```
4. Open `iDocs.xcworkspace`.

## Project Architecture
The project is split into two targets for better testability:
- `iDocsKit`: A static library containing the core logic (DataSources, Tools, Utils).
- `iDocs`: The executable entry point.
- `iDocsTests`: Unit tests targeting `iDocsKit`.

## Daily Development Workflow
- **Build**: `./scripts/tuist-silent.sh build iDocs`
- **Run Tests**: `./scripts/tuist-silent.sh test`
- **Clean**: `tuist clean`

## Verification Checklist
- [x] `tuist generate` completes under 10s (SC-001).
- [x] `tuist build` succeeds for the executable (SC-002).
- [x] `tuist test` executes all unit tests correctly (SC-003).
- [x] Zero manual Xcode configuration required (SC-004).
