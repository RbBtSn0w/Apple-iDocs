# Contract: Retrieval Source Policy

## Scope

Applies to `search` and `fetch` operations.

## Policy

### Search
1. Cache/local layer first
2. Apple remote second
3. sosumi remote third

### Fetch
1. Cache layer first
2. Local Xcode second
3. Apple remote third
4. sosumi remote fourth

## Fallback Rules

- A source attempt is considered fallback-eligible when:
  - returns no matching result/content, or
  - fails with recoverable retrieval error.
- First successful hit terminates the chain.
- If all sources fail/miss, return standardized terminal error.

## Observability

Successful responses MUST include source hit value in allowed set:
- `cache`, `local`, `apple`, `sosumi`
