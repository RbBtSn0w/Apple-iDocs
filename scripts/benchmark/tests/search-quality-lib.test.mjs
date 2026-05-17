import assert from "node:assert/strict";
import test from "node:test";

import {
  actionableIDocsFailures,
  caseCapability,
  classifyProductResult,
  computeFailureFingerprint,
  createSeededSampler,
  isP0IssueEligible,
  parsePackageSpecs,
  redactRawEvidence,
  redactSensitiveValues,
  summarizeProducts
} from "../search-quality-lib.mjs";

const pool = [
  {
    id: "swiftui-symbol",
    framework: "SwiftUI",
    queryShape: "exact_symbol",
    query: "SwiftUI NavigationSplitView",
    expectedOutcome: "canonical_doc",
    canonicalPaths: ["/documentation/swiftui/navigationsplitview"],
    requiredTerms: ["NavigationSplitView"],
    sourceFamily: "documentation",
    ciEligible: true
  },
  {
    id: "appkit-member",
    framework: "AppKit",
    queryShape: "member_property",
    query: "NSWindow toolbarStyle",
    expectedOutcome: "canonical_doc",
    canonicalPaths: ["/documentation/appkit/nswindow/toolbarstyle"],
    requiredTerms: ["toolbarStyle"],
    sourceFamily: "documentation",
    ciEligible: true
  },
  {
    id: "excluded-case",
    framework: "UIKit",
    queryShape: "natural_language",
    query: "How do I present a sheet?",
    expectedOutcome: "canonical_doc",
    canonicalPaths: ["/documentation/uikit/uiviewcontroller/present"],
    requiredTerms: ["present"],
    sourceFamily: "documentation",
    ciEligible: false
  },
  {
    id: "invalid-case",
    framework: "Foundation",
    queryShape: "invalid_no_result",
    query: "DefinitelyNotAppleAPI999",
    expectedOutcome: "invalid_no_result",
    canonicalPaths: [],
    requiredTerms: [],
    sourceFamily: "documentation",
    ciEligible: true
  }
];

test("seeded sampler is deterministic and excludes ciEligible=false cases", () => {
  const sampleA = createSeededSampler(pool, { seed: 7, sampleSize: 3 });
  const sampleB = createSeededSampler(pool, { seed: 7, sampleSize: 3 });
  const sampleC = createSeededSampler(pool, { seed: 8, sampleSize: 3 });

  assert.deepEqual(sampleA.map(item => item.id), sampleB.map(item => item.id));
  assert.notDeepEqual(sampleA.map(item => item.id), sampleC.map(item => item.id));
  assert.equal(sampleA.some(item => item.id === "excluded-case"), false);
});

test("classification covers symbol, module-only, empty, wrong framework, wrong page, unsupported, and network error", () => {
  const canonicalCase = pool[0];
  assert.equal(classifyProductResult(canonicalCase, { path: "/documentation/swiftui/navigationsplitview", text: "NavigationSplitView" }).classification, "symbol_hit");
  assert.equal(classifyProductResult(canonicalCase, { path: "/documentation/swiftui", text: "SwiftUI framework" }).classification, "module_only");
  assert.equal(classifyProductResult(canonicalCase, { results: [] }).classification, "empty");
  assert.equal(classifyProductResult(canonicalCase, { path: "/documentation/appkit/nsview", text: "NSView" }).classification, "wrong_framework");
  assert.equal(classifyProductResult(canonicalCase, { path: "/documentation/swiftui/list", text: "List" }).classification, "wrong_page");
  assert.equal(classifyProductResult(canonicalCase, { path: "/videos/wwdc2026", unsupported: true }).classification, "unsupported_misclassified");
  assert.equal(classifyProductResult(canonicalCase, { error: "ECONNRESET", networkError: true }).classification, "network_error");
});

test("verdict applies invalid/no-result and module-only rules", () => {
  const invalid = classifyProductResult(pool[3], { results: [] });
  assert.equal(invalid.classification, "empty");
  assert.equal(invalid.verdict, "pass");

  const moduleOnly = classifyProductResult(pool[0], { path: "/documentation/swiftui", text: "SwiftUI framework" });
  assert.equal(moduleOnly.classification, "module_only");
  assert.equal(moduleOnly.verdict, "fail");

  const network = classifyProductResult(pool[0], { error: "timeout", networkError: true });
  assert.equal(network.classification, "network_error");
  assert.equal(network.verdict, "infra");
});

test("classification treats Apple Swift slug variants as canonical path hits", () => {
  const result = classifyProductResult({
    framework: "AppKit",
    expectedOutcome: "canonical_doc",
    canonicalPaths: ["/documentation/appkit/nswindow/toolbarstyle"]
  }, {
    path: "/documentation/appkit/nswindow/toolbarstyle-swift.property",
    text: "toolbarStyle"
  });

  assert.equal(result.classification, "symbol_hit");
  assert.equal(result.verdict, "pass");
});

test("issue fingerprint is stable regardless of failing case order", () => {
  const failures = [
    { caseId: "b", expectedOutcome: "canonical_doc", classification: "module_only" },
    { caseId: "a", expectedOutcome: "canonical_doc", classification: "empty" }
  ];
  const reversed = [...failures].reverse();

  assert.equal(computeFailureFingerprint(failures), computeFailureFingerprint(reversed));
});

test("case capability defaults and validation separate resolve fetch and search", () => {
  assert.equal(caseCapability({ capability: "resolve" }), "resolve");
  assert.equal(caseCapability({ capability: "fetch" }), "fetch");
  assert.equal(caseCapability({ capability: "search" }), "search");
  assert.equal(caseCapability({ queryShape: "natural_language" }), "search");
  assert.throws(() => caseCapability({ capability: "browser" }), /unsupported capability/);
});

test("P0 issue eligibility excludes search exploration failures by default", () => {
  const results = [
    {
      caseId: "search-natural-language",
      targetId: "idocs",
      capability: "search",
      verdict: "fail",
      classification: "wrong_page",
      expectedOutcome: "canonical_doc"
    },
    {
      caseId: "resolve-swiftui-navigation",
      targetId: "idocs",
      capability: "resolve",
      p0IssueEligible: true,
      verdict: "fail",
      classification: "empty",
      expectedOutcome: "canonical_doc"
    },
    {
      caseId: "fetch-swiftui-navigation",
      targetId: "idocs",
      capability: "fetch",
      p0IssueEligible: true,
      verdict: "fail",
      classification: "wrong_page",
      expectedOutcome: "canonical_doc"
    }
  ];

  assert.equal(isP0IssueEligible(results[0]), false);
  assert.equal(isP0IssueEligible(results[1]), true);
  assert.equal(isP0IssueEligible(results[2]), true);
  assert.deepEqual(
    actionableIDocsFailures(results).map(result => result.caseId),
    ["resolve-swiftui-navigation", "fetch-swiftui-navigation"]
  );
});

test("product summary counts verdicts by target", () => {
  const summary = summarizeProducts([
    { targetId: "idocs", verdict: "pass" },
    { targetId: "idocs", verdict: "fail" },
    { targetId: "sosumi", verdict: "infra" },
    { targetId: "sosumi", verdict: "not_applicable" }
  ]);

  assert.deepEqual(summary.idocs, { pass: 1, fail: 1, infra: 0, not_applicable: 0 });
  assert.deepEqual(summary.sosumi, { pass: 0, fail: 0, infra: 1, not_applicable: 1 });
});

test("redaction removes token-like environment values", () => {
  const redacted = redactSensitiveValues("GITHUB_TOKEN=ghp_secret NODE_AUTH_TOKEN=npm_secret ok");
  assert.equal(redacted.includes("ghp_secret"), false);
  assert.equal(redacted.includes("npm_secret"), false);
  assert.equal(redacted.includes("[REDACTED]"), true);

  const raw = redactRawEvidence({ stderr: "GH_TOKEN=github_pat_secret", nested: ["npm_secret"] });
  assert.equal(JSON.stringify(raw).includes("github_pat_secret"), false);
  assert.equal(JSON.stringify(raw).includes("npm_secret"), false);
});

test("package spec parser rejects unsupported npm alias specs", () => {
  assert.throws(
    () => parsePackageSpecs("apple-doc-mcp-server@npm:apple-doc-mcp-server@1.9.1"),
    /npm alias package specs are not supported/
  );
});
