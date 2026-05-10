# Feature Specification: CLI Version Support

**Feature Branch**: `010-fix-cli-version`  
**Created**: Sunday, May 10, 2026  
**Status**: Draft  
**Input**: User description: "Add missing --version support in idocs CLI and decouple it from coreVersion"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Check CLI Version (Priority: P1)

As a developer using the `idocs` tool, I want to be able to run `idocs --version` to see which version of the CLI I am using, so I can ensure I'm on the latest release and report bugs with accurate version info.

**Why this priority**: Fundamental CLI feature for supportability and user confidence. It allows users to distinguish between the CLI tool version and the internal core/adapter versions.

**Independent Test**: Can be tested by running `idocs --version` or `idocs -v` and verifying it returns the expected release version string (e.g., "1.3.1").

**Acceptance Scenarios**:

1. **Given** the CLI is installed, **When** I run `idocs --version`, **Then** the current release version is printed to the console.
2. **Given** the CLI is installed, **When** I run `idocs -v`, **Then** the current release version is printed to the console.

---

### User Story 2 - Discover Version Command via Help (Priority: P2)

As a new user, I want to see the version command listed when I run `idocs --help`, so I know how to check the version without guessing the flag.

**Why this priority**: Standard CLI UX behavior. Users expect `--version` to be a discoverable global flag.

**Independent Test**: Run `idocs --help` and verify the output contains the version option.

**Acceptance Scenarios**:

1. **Given** the CLI is installed, **When** I run `idocs --help`, **Then** `--version` (and its alias `-v`) is listed in the available options.

---

### Edge Cases

- **Version formatting**: Ensure the output is clean (just the version number or a short prefix like "idocs version 1.3.1") to be easily parsable by other scripts.
- **Pre-release versions**: Ensure that if a pre-release version is installed (e.g., 1.3.2-alpha.1), it is correctly reported.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support `--version` as a global flag.
- **FR-002**: System MUST support `-v` as a shorthand alias for `--version`.
- **FR-003**: System MUST output the distribution version that matches the published package version (e.g., "1.3.1").
- **FR-004**: CLI Version output MUST be decoupled from the internal `coreVersion` (which represents Adapter/Core ABI compatibility).
- **FR-005**: Running the version command MUST NOT execute any other business logic (like searching or fetching) or require an internet connection.
- **FR-006**: The version information MUST be included in the output of the `--help` command.

### Key Entities

- **Release Version**: The public-facing version of the idocs tool, typically following Semantic Versioning (SemVer), as defined in the project's distribution metadata (e.g., package.json).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running `idocs --version` returns the version string in under 100ms.
- **SC-002**: 100% of help command executions (`idocs --help`) include the version flag documentation.
- **SC-003**: The version reported by the CLI exactly matches the version defined in the distribution manifest (package.json).
