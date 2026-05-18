# Feature Specification: Resilient DocC Ingestion

**Feature Branch**: `015-resilient-docc-ingestion`  
**Created**: 2026-05-19  
**Status**: Verified  
**Input**: User description: "Implement the balanced 015 design: keep iDocs Swift-native and public models stable, but add a tolerant Apple remote DocC ingestion boundary using typed loose JSON, partial rendering, and path-aware diagnostics so Apple schema drift does not unnecessarily stop fetch."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fetch Apple Documentation Despite Non-Critical Schema Drift (Priority: P1)

As an agent using iDocs for Apple documentation evidence, I need `idocs fetch` to return useful Apple-sourced documentation when Apple remote DocC JSON contains unknown or newly shaped non-critical nodes, so that a minor upstream schema drift does not force fallback to less authoritative sources.

**Why this priority**: This preserves Apple as the canonical evidence source for reachable documentation pages while reducing breakage from Apple internal payload changes.

**Independent Test**: Can be tested by simulating cache/local misses and Apple remote JSON that contains a valid title, identifier, abstract, and renderable content plus unknown nested content shapes; fetch should return Apple as the source with partial decode diagnostics instead of falling back.

**Acceptance Scenarios**:

1. **Given** cache and local content miss, **When** Apple returns documentation JSON with required core fields plus unknown non-critical content nodes, **Then** fetch returns Apple-sourced markdown containing the known title and renderable content.
2. **Given** Apple remote content is partially normalized, **When** source attempts are reported, **Then** the source chain stops at Apple and does not call fallback sources.
3. **Given** unknown non-critical nodes are skipped, **When** diagnostics are inspected, **Then** they identify partial remote decoding and include the affected JSON path.

---

### User Story 2 - Preserve Stable Public Output and Cache Shape (Priority: P2)

As a maintainer of iDocs consumers and cache files, I need Apple remote schema tolerance to stay internal to ingestion, so that callers, adapters, renderers, and disk cache continue to consume the same stable `DocCContent` shape.

**Why this priority**: Tolerance should reduce upstream breakage without making the iDocs public contract drift with Apple internal JSON.

**Independent Test**: Can be tested by normalizing a tolerant Apple payload and encoding the resulting content; the encoded content should use the stable iDocs shape rather than the loose Apple input shape.

**Acceptance Scenarios**:

1. **Given** Apple remote JSON uses alternate or unknown shapes, **When** iDocs normalizes it successfully, **Then** the returned content exposes the stable iDocs documentation content fields.
2. **Given** normalized content is encoded for cache or tests, **When** the payload is inspected, **Then** it does not contain loose raw JSON wrappers for public fields.
3. **Given** existing stable DocC JSON is decoded, **When** it passes through the ingestion changes, **Then** its behavior and encoded output remain unchanged.

---

### User Story 3 - Fail Clearly When Required Core Evidence Is Missing (Priority: P3)

As an iDocs maintainer, I need genuinely unusable Apple documentation payloads to fail with precise diagnostics, so that required evidence gaps remain visible and fallback behavior still works.

**Why this priority**: Tolerant ingestion must not silently turn malformed or non-documentation payloads into misleading evidence.

**Independent Test**: Can be tested by simulating Apple remote JSON missing required core evidence; fetch should record a path-aware remote decode failure and continue existing fallback behavior.

**Acceptance Scenarios**:

1. **Given** Apple remote JSON lacks a usable title and identifier, **When** `idocs fetch` processes the response, **Then** Apple is rejected and fallback behavior continues.
2. **Given** Apple remote JSON is rejected, **When** diagnostics are inspected, **Then** the failure reason identifies the required missing path rather than only a generic decode failure.
3. **Given** invalid Apple content is followed by a successful fallback, **When** source attempts are reported, **Then** existing source ordering remains cache, local, Apple, fallback.

### Edge Cases

- Unknown content block type appears inside primary content: known sibling content still renders and a partial diagnostic records the unknown block path.
- Unknown inline content appears inside abstract or paragraphs: known inline text still renders where possible and a partial diagnostic records the skipped inline path.
- Unknown reference entries appear in the references map: known references remain available and unknown entries are skipped with diagnostics.
- Required core evidence is missing: the response fails and fallback behavior continues.
- Existing stable cache/local JSON: continues to decode through the stable model without requiring tolerant remote ingestion.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST keep the public documentation content model and encoded cache shape stable for callers.
- **FR-002**: The system MUST isolate loose Apple remote JSON handling inside the Apple remote ingestion boundary.
- **FR-003**: The system MUST use typed loose JSON representation rather than untyped runtime dictionaries for unknown Apple JSON shapes.
- **FR-004**: The system MUST normalize tolerant Apple remote content into the existing stable documentation content model before rendering or caching.
- **FR-005**: The system MUST return Apple as the selected source when required core evidence is present and at least one meaningful content section can be rendered, even if non-critical nodes are skipped.
- **FR-006**: The system MUST preserve fetch source ordering: cache, local, Apple, then fallback sources only when Apple cannot produce usable content.
- **FR-007**: The system MUST record partial remote decode diagnostics with affected JSON paths whenever unknown non-critical nodes are skipped.
- **FR-008**: The system MUST reject Apple remote content that lacks required core evidence and record path-aware remote decode failure diagnostics.
- **FR-009**: The system MUST preserve existing fallback behavior for genuinely unusable Apple content.
- **FR-010**: The system MUST NOT introduce Node, Python, MCP runtime, database, or service dependencies into the shipped CLI path.

#### iDocs Constitution Alignment

- This feature touches `fetch` as the primary capability.
- `fetch` remains the canonical evidence authority for known paths, with `search` still limited to exploration and candidate discovery.
- CLI output compatibility is required: source reporting and fetch diagnostics must remain stable while adding more precise diagnostic reasons where available.
- No new runtime dependency is required; the shipped CLI remains Swift-native and CLI-only.

### Key Entities

- **Stable Documentation Content**: The public content model consumed by renderers, adapters, cache files, and callers.
- **Apple Remote Payload**: The upstream DocC JSON payload returned by Apple documentation endpoints.
- **Typed Loose JSON Value**: A Swift-native representation of unknown JSON object, array, string, number, boolean, and null values used only at the ingestion boundary.
- **Normalization Result**: The result of transforming a loose Apple payload into stable documentation content plus diagnostics.
- **Partial Decode Diagnostic**: A path-aware diagnostic describing skipped non-critical nodes.
- **Remote Decode Failure Diagnostic**: A path-aware diagnostic describing missing required evidence or an unusable payload.

### Assumptions

- This feature targets Apple remote DocC payloads only; cache and local Xcode docs continue to prefer the stable model path.
- The first implementation focuses on high-value fallback prevention for title, identifier, abstract, primary content sections, topic sections, references, and unknown content/inline nodes.
- Future DocC schema drift should be handled by adding small normalization rules and tests rather than exposing raw Apple schema to public callers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of test payloads with required core evidence and unknown non-critical content return Apple as the selected source.
- **SC-002**: 100% of successful partial Apple fetches include at least one path-aware partial decode diagnostic.
- **SC-003**: 100% of successful partial Apple fetches stop before fallback sources.
- **SC-004**: 100% of normalized content encoded for cache uses the stable iDocs content shape.
- **SC-005**: 100% of test payloads missing required core evidence continue existing fallback behavior with path-aware failure diagnostics.
