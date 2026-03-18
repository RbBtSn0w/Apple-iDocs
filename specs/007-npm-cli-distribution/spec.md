# Feature Specification: npm Distribution for iDocs CLI

**Feature Branch**: `007-npm-cli-distribution`  
**Created**: 2026-03-18  
**Status**: Draft  
**Input**: "Provide npm-managed distribution and local registration flow for the Swift-based `idocs` CLI."

## User Scenarios & Testing

### User Story 1 - Install from npm (Priority: P1)

As a CLI user, I want to install `idocs` from npm so I can use the command without setting up Swift/Tuist.

**Independent Test**: Install package from npm/tgz and run `idocs --help`.

**Acceptance Scenarios**:
1. **Given** a valid package release, **When** I install with npm, **Then** `idocs` is available on PATH.
2. **Given** successful installation, **When** I run `idocs search "SwiftUI"`, **Then** it executes with expected CLI output.

### User Story 2 - Local Developer Registration (Priority: P1)

As a maintainer, I want local npm link registration so I can quickly test packaging behavior before publishing.

**Independent Test**: Build locally, run local link command, and execute `idocs --help`.

**Acceptance Scenarios**:
1. **Given** a local Debug build exists, **When** I run local link script and `npm link`, **Then** global `idocs` resolves to local binary.
2. **Given** local binary is missing, **When** I run link command, **Then** actionable build instructions are printed.

### User Story 3 - Release Asset Compatibility (Priority: P2)

As a releaser, I want deterministic release asset naming so npm postinstall can download and install reliably.

**Independent Test**: Run release packaging script and verify expected tarball/checksum outputs.

**Acceptance Scenarios**:
1. **Given** release build succeeds, **When** packaging runs, **Then** `idocs-darwin-arm64.tar.gz` is generated.
2. **Given** package version and release URL pattern, **When** postinstall runs, **Then** it resolves the correct download URL.

## Functional Requirements

- **FR-001**: System MUST provide an npm package entrypoint that exposes `idocs` as executable command.
- **FR-002**: System MUST support macOS arm64 as first release platform target.
- **FR-003**: System MUST download prebuilt release asset during npm installation.
- **FR-004**: System MUST support local development registration via `npm link` without publishing.
- **FR-005**: System MUST provide deterministic release artifact naming for installer compatibility.
- **FR-006**: System MUST document install, local registration, and release packaging workflows.

## Success Criteria

- **SC-001**: `npm install -g <package>` results in runnable `idocs --help` on macOS arm64.
- **SC-002**: `npm --prefix npm run link-local && npm --prefix npm link` enables local `idocs` command.
- **SC-003**: `scripts/release-package.sh` consistently produces expected release assets.
