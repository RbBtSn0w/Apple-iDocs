# Feature Specification: Search Quality Race CI

**Feature Branch**: `012-search-quality-race`  
**Created**: Saturday, May 16, 2026  
**Status**: Verified  
**Input**: User description: "Search Quality Race CI: scheduled and manual search-quality audit comparing idocs against public competitor releases with reproducible reports, artifacts, and automated issue collection for idocs golden-truth failures."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Monitor Search Quality on a Recurring Cadence (Priority: P1)

As an iDocs maintainer, I want a recurring repository quality audit to run without manual setup, so search regressions are detected and summarized even when no pull request is active.

**Why this priority**: Search quality is a product reliability signal, not just a development-time check. A recurring audit makes drift visible while keeping quality regressions separate from infrastructure failures.

**Independent Test**: Can be tested by triggering the audit on demand and verifying it produces the same report surfaces as a scheduled run, including run metadata, product-level results, iDocs failures, comparison tables, and retained artifacts.

**Acceptance Scenarios**:

1. **Given** the repository is on its default branch, **When** the scheduled audit time arrives, **Then** a search-quality audit run is started automatically.
2. **Given** a maintainer needs immediate feedback, **When** they trigger the audit manually, **Then** the audit accepts explicit sampling and package-selection inputs for that run.
3. **Given** iDocs has search-quality failures but the audit infrastructure completes successfully, **When** the run finishes, **Then** the run is reported as completed while the quality failures are captured in the report and issue workflow.
4. **Given** the audit cannot build the current iDocs CLI, install required competitor releases, execute the runner, or write reports, **When** the run finishes, **Then** the run is marked as an infrastructure failure.

---

### User Story 2 - Compare iDocs Against Public Competitor Releases (Priority: P1)

As an iDocs maintainer, I want iDocs and competitor tools to run against the same seeded audit sample, so quality comparisons are reproducible and fair across products.

**Why this priority**: The race is only meaningful if every product sees the same cases and competitor versions are traceable to exact public releases.

**Independent Test**: Can be tested by running the audit twice with the same seed and sample size and verifying the sampled case set is identical, then running with a different seed and verifying the sample can change while still respecting eligibility and strata.

**Acceptance Scenarios**:

1. **Given** the audit has a seed and sample size, **When** the case sample is selected, **Then** the same seed and sample size produce the same case IDs in the same order.
2. **Given** the audit case pool contains non-CI-eligible cases, **When** the sample is selected, **Then** no non-CI-eligible case is included.
3. **Given** public competitor releases are installed for a run, **When** the report is generated, **Then** the exact resolved version for every competitor product is recorded.
4. **Given** iDocs and competitors evaluate a case, **When** results are reported, **Then** every product row is tied to the same audit case, query, expected outcome, and canonical expectation.

---

### User Story 3 - Review Search Quality Evidence Quickly (Priority: P1)

As an iDocs maintainer, I want a concise run summary plus a complete retained artifact, so I can scan the current quality picture quickly and still inspect raw evidence when needed.

**Why this priority**: Maintainers need a fast signal in the run UI, but debugging a failure requires full case-level evidence, product versions, diagnostics, and reproduction commands.

**Independent Test**: Can be tested by completing an audit run and verifying the run summary contains the required tables while the retained artifact contains complete case records and raw evidence.

**Acceptance Scenarios**:

1. **Given** an audit run completes, **When** the run summary is viewed, **Then** it shows metadata including seed, sample size, commit, iDocs binary identity, and competitor versions.
2. **Given** the audit evaluated multiple products, **When** the summary is viewed, **Then** it includes product-level pass, fail, infrastructure, and not-applicable counts.
3. **Given** failures occurred, **When** the summary is viewed, **Then** it includes a failure heatmap by query shape, framework, product, and failure class.
4. **Given** iDocs has golden-truth failures, **When** the summary is viewed, **Then** each iDocs failure shows the case, query, expectation, classification, top evidence, and local reproduction command.
5. **Given** a maintainer needs full details, **When** they open the retained artifact, **Then** it contains the complete audit record, rendered report, versions, seed, sample set, diagnostics, and raw evidence needed for debugging.

---

### User Story 4 - Collect iDocs Golden-Truth Failures Automatically (Priority: P1)

As an iDocs maintainer, I want repository issues to be created or updated only for iDocs golden-truth failures, so actionable regressions are tracked without flooding the issue tracker with competitor or network noise.

**Why this priority**: The repository owns iDocs quality. Competitor failures are useful context, but only iDocs failures against the expected truth should create maintenance work.

**Independent Test**: Can be tested by running the audit with no iDocs failures, one simulated iDocs golden-truth failure, and the same simulated failure again; the first run should create no issue, then create one issue, then update the existing issue by fingerprint.

**Acceptance Scenarios**:

1. **Given** an audit run has no iDocs golden-truth failures, **When** issue collection runs, **Then** no issue is created or updated.
2. **Given** an audit run has iDocs golden-truth failures and no open issue with the same fingerprint, **When** issue collection runs, **Then** a new issue is created with the run URL, sample metadata, failing cases, diagnostics, competitor versions, artifact location, and reproduction command.
3. **Given** an open issue already contains the same failure fingerprint, **When** issue collection runs again, **Then** the existing issue receives a new comment with the latest run URL and report links instead of creating a duplicate issue.
4. **Given** an iDocs result is classified as network or infrastructure noise, **When** issue collection runs, **Then** that result is excluded from issue fingerprinting and issue creation.
5. **Given** preferred labels are unavailable, **When** an issue must be created, **Then** label application is skipped or partially applied without blocking issue creation.

---

### User Story 5 - Keep the Race Remote-Only for CI (Priority: P2)

As an iDocs maintainer, I want CI audit results to exclude local Xcode documentation cache effects, so the race measures public remote behavior consistently across runners.

**Why this priority**: Local Xcode documentation availability varies by machine. The race should be reproducible in CI and must not imply that local cache capabilities were compared.

**Independent Test**: Can be tested by running the audit in remote-only mode and verifying the iDocs result preserves a local-documentation-unavailable diagnostic while the report states that local Xcode comparison is excluded.

**Acceptance Scenarios**:

1. **Given** the audit is running in CI, **When** iDocs search is executed, **Then** local Xcode documentation cache access is intentionally unavailable for that run.
2. **Given** local documentation is unavailable, **When** iDocs emits diagnostics, **Then** the audit records the local-documentation-unavailable signal without treating it as a competitor-comparison dimension.
3. **Given** a reader reviews the report, **When** they interpret iDocs results, **Then** the report clearly states that local Xcode documentation comparison is excluded.

### Edge Cases

- The audit case pool contains ineligible cases; sampling must exclude them.
- A seed produces fewer eligible cases than the requested sample size; the report must state the actual sampled count and avoid duplicate cases unless explicitly allowed.
- A competitor public release cannot be installed or resolved; the run must fail as infrastructure, not quality.
- A competitor returns no result, malformed output, or unsupported behavior; that product receives a case-level classification and verdict without blocking the full audit unless the runner itself cannot continue.
- iDocs returns an empty result for an invalid/no-result case; this can be a pass when it matches the expected outcome.
- iDocs returns only a broad module or framework page for a symbol/member query; this is a fail unless the case explicitly allows module-level success.
- A network error occurs for iDocs or a competitor; the result is classified separately from golden-truth quality failures and does not create an iDocs issue.
- Report generation succeeds but issue creation fails because of repository permissions; the run should surface the issue-collection problem as infrastructure only if the configured issue path cannot complete as required.
- Preferred labels do not exist; issue creation still proceeds.
- The same failing case IDs appear in a different order; the fingerprint remains stable.
- A manual run requests a simulated failure; the report and issue collector must mark it as a test of the automation path rather than a product regression.
- Sensitive environment values must not appear in summaries, artifacts, issue bodies, or comments.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST provide a search-quality audit that runs on a recurring nightly schedule and can also be triggered manually by a maintainer.
- **FR-002**: Manual audit runs MUST allow maintainers to override at least the random seed, sample size, competitor package selection, and simulated-failure mode for validation.
- **FR-003**: The audit MUST build and evaluate the current repository version of the iDocs CLI for the commit under test.
- **FR-004**: The audit MUST evaluate competitor products from public npm releases and record the exact resolved version for each competitor product in every report.
- **FR-005**: The default competitor set MUST include the Apple documentation competitors identified for this benchmark unless a manual run explicitly overrides the package selection.
- **FR-006**: The audit MUST select cases from a seeded stratified random pool so the same seed and sample size produce a reproducible sample.
- **FR-007**: The audit MUST exclude cases where `ciEligible` is false.
- **FR-008**: Each audit case MUST record a stable ID, framework or product area, query shape, query, expected outcome, canonical paths, required terms, source family, CI eligibility, and runner hints when applicable.
- **FR-009**: The initial audit pool MUST cover SwiftUI, AppKit, UIKit, Foundation, Xcode, and App Store Connect cases.
- **FR-010**: The initial audit pool MUST cover exact-symbol, composite, member-property, natural-language, fuzzy-typo, and invalid/no-result query shapes.
- **FR-011**: Every product result for every sampled case MUST include a classification from the supported set: symbol hit, module-only, empty result, wrong framework, wrong page, unsupported or misclassified, and network error.
- **FR-012**: Every product result for every sampled case MUST include a verdict from the supported set: pass, fail, infrastructure, and not applicable.
- **FR-013**: Empty results MUST be considered passing only when the case expectation is invalid/no-result or otherwise explicitly declares empty as acceptable.
- **FR-014**: Module-only results for symbol or member queries MUST be considered failing unless the case explicitly declares module-level success as acceptable.
- **FR-015**: The audit MUST run iDocs in remote-only mode during CI and preserve a local-documentation-unavailable diagnostic in the report.
- **FR-016**: CI reports MUST clearly state that local Xcode documentation comparison is excluded from the competitor race.
- **FR-017**: Search-quality failures MUST NOT fail the audit run when the audit infrastructure itself completes successfully.
- **FR-018**: Infrastructure failures MUST fail the audit run when the audit cannot build iDocs, resolve competitor releases, execute the audit, generate reports, upload artifacts, or complete required issue collection.
- **FR-019**: Each completed audit MUST produce a complete machine-readable audit artifact containing run metadata, product versions, seed, sample set, per-case results, diagnostics, and raw evidence.
- **FR-020**: Each completed audit MUST produce a human-readable artifact report summarizing the same run.
- **FR-021**: Each completed audit MUST write a run summary with sections for metadata, product summary, failure heatmap, iDocs failures, and cross-product comparison.
- **FR-022**: iDocs failure rows MUST include the case ID, query, expectation, classification, top evidence, and a local reproduction command.
- **FR-023**: Cross-product comparison rows MUST present iDocs and all competitor products side by side for the same case.
- **FR-024**: Issue collection MUST consider only iDocs verdicts that are golden-truth failures and MUST ignore competitor failures, not-applicable results, network errors, and infrastructure failures.
- **FR-025**: Issue collection MUST compute a stable fingerprint from the sorted failing case IDs, expected outcomes, and iDocs classifications.
- **FR-026**: If an open issue already contains the same fingerprint, issue collection MUST append a comment with the latest run URL and report links instead of creating a duplicate issue.
- **FR-027**: If no open issue contains the fingerprint, issue collection MUST create a new issue containing the run URL, seed, sample size, failing cases, iDocs diagnostics, competitor versions, artifact location, and local reproduction command.
- **FR-028**: Preferred labels for search quality, automation, and benchmarks MUST be applied on a best-effort basis and MUST NOT block issue creation.
- **FR-029**: The audit MUST support a no-failure path that performs no issue mutation.
- **FR-030**: The audit MUST support a simulated iDocs failure path so issue creation and issue update behavior can be validated without requiring a real product regression.

### Key Entities

- **Audit Case**: A single query expectation with stable ID, product area, query shape, query text, expected outcome, canonical paths, required terms, source family, eligibility, and runner hints.
- **Audit Pool**: The eligible and ineligible case set from which seeded stratified samples are selected.
- **Audit Run**: One scheduled or manual execution with seed, sample size, commit identity, iDocs binary identity, competitor versions, selected cases, reports, artifacts, and issue-collection result.
- **Product Target**: iDocs or one competitor product evaluated against the same sampled cases.
- **Product Result**: A product's outcome for one audit case, including classification, verdict, evidence, diagnostics, and raw result references.
- **Classification**: The normalized result category used to compare products across heterogeneous outputs.
- **Verdict**: The actionability category for a product result: pass, fail, infrastructure, or not applicable.
- **Failure Fingerprint**: A stable identifier for the current set of actionable iDocs golden-truth failures.
- **Issue Record**: The repository issue or issue comment created to track actionable iDocs failures for one fingerprint.
- **Artifact Bundle**: The retained machine-readable and human-readable reports for a completed audit run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of completed audit runs include seed, sample size, commit identity, iDocs binary identity, and exact competitor versions in both the run summary and artifact report.
- **SC-002**: 100% of same-seed, same-sample-size audit selections produce the same ordered case IDs.
- **SC-003**: 0 non-CI-eligible cases are included in any default or manual audit sample.
- **SC-004**: 100% of sampled product-case results include both a normalized classification and verdict.
- **SC-005**: 100% of invalid/no-result cases classify empty iDocs results as passing when empty is the expected outcome.
- **SC-006**: 100% of symbol/member cases classify module-only iDocs results as failing unless the case explicitly permits module-level success.
- **SC-007**: 100% of completed CI audit reports include the remote-only diagnostic and state that local Xcode documentation comparison is excluded.
- **SC-008**: 100% of completed audit runs upload both the complete machine-readable artifact and the human-readable artifact report.
- **SC-009**: 100% of iDocs golden-truth failures shown in the summary include case ID, query, expectation, classification, top evidence, and a local reproduction command.
- **SC-010**: 100% of no-failure audit runs perform no issue creation or issue update.
- **SC-011**: 100% of actionable iDocs golden-truth failure sets create a new issue when no open issue has the same fingerprint.
- **SC-012**: 100% of repeated actionable iDocs golden-truth failure sets update the matching open issue rather than creating a duplicate issue.
- **SC-013**: Search-quality failures alone produce a completed audit result, while build, package-resolution, runner, report, artifact, and required issue-collection failures produce an infrastructure failure.
- **SC-014**: Maintainers can validate issue creation and issue update behavior through a simulated-failure manual run without requiring a real search regression.

## Assumptions

- The audit is a quality-monitoring signal, not a pull-request merge gate.
- Competitor products are evaluated from public npm releases, not cloned source repositories.
- The default sample size is 40 unless a manual run overrides it.
- The default competitor set is `@kimsungwhee/apple-docs-mcp`, `apple-doc-mcp-server`, and `@nshipster/sosumi`.
- The repository issue tracker is the destination for actionable iDocs golden-truth failures.
- Detailed workflow runner selection, script file names, package installation mechanics, and unit-test file placement are planning and implementation details, not specification requirements.

## Source Coverage Traceability

- **Nightly and manual CI**: Covered by User Story 1, FR-001, FR-002, SC-001, SC-013, and SC-014.
- **Competitor npm releases and exact versions**: Covered by User Story 2, FR-004, FR-005, SC-001, and Assumptions.
- **Seeded stratified random audit input**: Covered by User Story 2, FR-006 through FR-010, SC-002, and SC-003.
- **Remote-only iDocs behavior**: Covered by User Story 5, FR-015, FR-016, and SC-007.
- **Classification and verdict rules**: Covered by FR-011 through FR-014 and SC-004 through SC-006.
- **Report and artifact structure**: Covered by User Story 3, FR-019 through FR-023, SC-001, SC-008, and SC-009.
- **Issue creation and de-duplication**: Covered by User Story 4, FR-024 through FR-030, SC-010 through SC-012, and SC-014.
- **Infrastructure-versus-quality failure policy**: Covered by User Story 1, FR-017, FR-018, and SC-013.
