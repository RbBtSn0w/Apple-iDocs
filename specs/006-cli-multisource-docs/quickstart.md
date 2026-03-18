# Quickstart: Validate CLI Multi-Source Retrieval

## 1) Generate and Build

```bash
tuist install
tuist generate
./scripts/tuist-silent.sh build iDocs
```

## 2) Basic CLI Contract Check

```bash
./scripts/tuist-silent.sh run idocs --help
./scripts/tuist-silent.sh run idocs search "SwiftUI"
./scripts/tuist-silent.sh run idocs fetch "/documentation/swiftui/view"
```

## 3) Local Layer Validation

- Ensure Xcode documentation cache exists under:
  - `~/Library/Developer/Xcode/DocumentationCache`
- Run search/fetch and verify local hit behavior where applicable.

## 4) Remote Fallback Validation

- Simulate or mock Apple remote miss/failure.
- Verify fallback to sosumi source for search/fetch.
- Verify source-hit observability in output/log assertions.

## 5) Test Suite

```bash
./scripts/tuist-silent.sh test
./scripts/arch-gate.sh
```

## 6) Expected Outcome

- `search` and `fetch` execute deterministic layered retrieval.
- Source-hit is observable (`cache/local/apple/sosumi`).
- CLI error and exit semantics remain stable.
