import crypto from "node:crypto";

export const DEFAULT_PACKAGE_SPECS = [
  "@kimsungwhee/apple-docs-mcp@latest",
  "apple-doc-mcp-server@latest",
  "@nshipster/sosumi@latest"
];

export const DEFAULT_TARGETS = [
  { id: "idocs", displayName: "iDocs", kind: "idocs" },
  { id: "apple-docs-mcp", displayName: "apple-docs-mcp", kind: "competitor", packageName: "@kimsungwhee/apple-docs-mcp" },
  { id: "apple-doc-mcp", displayName: "apple-doc-mcp", kind: "competitor", packageName: "apple-doc-mcp-server" },
  { id: "sosumi", displayName: "sosumi", kind: "competitor", packageName: "@nshipster/sosumi" }
];

const DEFAULT_COUNTS = Object.freeze({
  pass: 0,
  fail: 0,
  infra: 0,
  not_applicable: 0
});

export function createSeededSampler(pool, { seed = 1, sampleSize = 40 } = {}) {
  const eligible = pool.filter(testCase => testCase.ciEligible !== false);
  const groups = new Map();

  for (const testCase of eligible) {
    const key = `${testCase.framework ?? "unknown"}::${testCase.queryShape ?? "unknown"}`;
    const group = groups.get(key) ?? [];
    group.push(testCase);
    groups.set(key, group);
  }

  const rng = mulberry32(seedToNumber(seed));
  const shuffledGroups = shuffle([...groups.values()], rng)
    .map(group => shuffle(group, rng));

  const sample = [];
  let index = 0;
  while (sample.length < sampleSize) {
    let added = false;
    for (const group of shuffledGroups) {
      if (index < group.length && sample.length < sampleSize) {
        sample.push(group[index]);
        added = true;
      }
    }
    if (!added) break;
    index += 1;
  }

  return sample;
}

export function classifyProductResult(testCase, rawResult = {}) {
  const normalized = normalizeRawResult(rawResult);

  if (normalized.networkError) {
    return buildClassification("network_error", "infra", normalized);
  }

  if (normalized.unsupported) {
    return buildClassification("unsupported_misclassified", "fail", normalized);
  }

  if (normalized.empty) {
    const pass = testCase.expectedOutcome === "invalid_no_result" || testCase.allowEmpty === true;
    return buildClassification("empty", pass ? "pass" : "fail", normalized);
  }

  const canonicalPaths = (testCase.canonicalPaths ?? []).map(normalizePath);
  const actualPath = normalizePath(normalized.path ?? "");
  const expectedFramework = String(testCase.framework ?? "").toLowerCase();

  if (canonicalPaths.length > 0 && canonicalPaths.includes(actualPath)) {
    return buildClassification("symbol_hit", "pass", normalized);
  }

  if (isModuleOnlyPath(actualPath, expectedFramework)) {
    const pass = testCase.allowModuleOnly === true || testCase.expectedOutcome === "module_control";
    return buildClassification("module_only", pass ? "pass" : "fail", normalized);
  }

  if (expectedFramework && actualPath.includes("/documentation/") && !actualPath.includes(`/${expectedFramework}`)) {
    return buildClassification("wrong_framework", "fail", normalized);
  }

  return buildClassification("wrong_page", "fail", normalized);
}

export function computeFailureFingerprint(failures) {
  const stableInput = failures
    .map(failure => ({
      caseId: failure.caseId,
      expectedOutcome: failure.expectedOutcome,
      classification: failure.classification
    }))
    .sort((left, right) => left.caseId.localeCompare(right.caseId));

  return crypto
    .createHash("sha256")
    .update(JSON.stringify(stableInput))
    .digest("hex")
    .slice(0, 16);
}

export function summarizeProducts(results) {
  const summary = {};
  for (const result of results) {
    const targetId = result.targetId;
    summary[targetId] ??= { ...DEFAULT_COUNTS };
    if (Object.prototype.hasOwnProperty.call(summary[targetId], result.verdict)) {
      summary[targetId][result.verdict] += 1;
    }
  }
  return summary;
}

export function actionableIDocsFailures(results) {
  return results.filter(result =>
    result.targetId === "idocs"
      && result.verdict === "fail"
      && result.classification !== "network_error"
  );
}

export function parsePackageSpecs(input = DEFAULT_PACKAGE_SPECS.join(",")) {
  return String(input)
    .split(",")
    .map(item => item.trim())
    .filter(Boolean)
    .map(spec => {
      const atIndex = spec.startsWith("@")
        ? spec.indexOf("@", 1)
        : spec.lastIndexOf("@");
      if (atIndex <= 0) {
        return { packageName: spec, requestedSpec: "latest", raw: `${spec}@latest` };
      }
      return {
        packageName: spec.slice(0, atIndex),
        requestedSpec: spec.slice(atIndex + 1) || "latest",
        raw: spec
      };
    });
}

export function targetMetadataFromVersions(versions = {}, { idocsBinary = "idocs", installDir = null } = {}) {
  return DEFAULT_TARGETS.map(target => {
    if (target.id === "idocs") {
      return {
        ...target,
        binaryPath: idocsBinary,
        resolvedVersion: versions.idocs ?? idocsBinary
      };
    }
    const version = versions[target.id] ?? versions[target.packageName] ?? "unresolved";
    return {
      ...target,
      packageSpec: target.packageName,
      binaryPath: installDir ? `${installDir}/node_modules/.bin/${competitorBinName(target.id)}` : competitorBinName(target.id),
      resolvedVersion: version
    };
  });
}

export function renderAuditMarkdown(audit) {
  return [
    "# Random Search Audit",
    "",
    "## Run Metadata",
    "",
    renderRunMetadata(audit),
    "",
    "## Product Summary",
    "",
    renderProductSummary(audit),
    "",
    "## Failure Heatmap",
    "",
    renderFailureHeatmap(audit),
    "",
    "## iDocs Failures",
    "",
    renderIDocsFailures(audit),
    "",
    "## Competitor Comparison",
    "",
    renderCompetitorComparison(audit),
    ""
  ].join("\n");
}

export function renderRunMetadata(audit) {
  const versions = audit.targets
    .map(target => `${target.displayName}: ${target.resolvedVersion ?? target.binaryPath ?? "unknown"}`)
    .join("<br>");
  return renderMarkdownTable(
    ["Field", "Value"],
    [
      ["Seed", audit.seed],
      ["Sample size", `${audit.actualSampleSize}/${audit.sampleSize}`],
      ["Commit", audit.commitSha],
      ["iDocs binary", audit.idocsBinary],
      ["Remote-only", audit.remoteOnly ? "yes" : "no"],
      ["Simulated failure", audit.simulatedFailure ? "yes - automation validation path" : "no"],
      ["Competitor versions", versions]
    ]
  );
}

export function renderProductSummary(audit) {
  const summary = summarizeProducts(audit.results);
  const rows = Object.entries(summary).map(([product, counts]) => [
    product,
    counts.pass,
    counts.fail,
    counts.infra,
    counts.not_applicable
  ]);
  return renderMarkdownTable(["Product", "Pass", "Fail", "Infra", "N/A"], rows);
}

export function renderFailureHeatmap(audit) {
  const failures = audit.results.filter(result => result.verdict === "fail" || result.verdict === "infra");
  if (failures.length === 0) return "No failures recorded.";
  const counts = new Map();
  for (const result of failures) {
    const key = [result.queryShape, result.framework, result.targetId, result.classification].join("||");
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const rows = [...counts.entries()].map(([key, count]) => [...key.split("||"), count]);
  return renderMarkdownTable(["Query Shape", "Framework", "Product", "Failure Class", "Count"], rows);
}

export function renderIDocsFailures(audit) {
  const failures = actionableIDocsFailures(audit.results);
  if (failures.length === 0) return "No actionable iDocs golden-truth failures.";
  return renderMarkdownTable(
    ["Case", "Query", "Expected", "Classification", "Top Evidence", "repro command"],
    failures.map(failure => [
      failure.caseId,
      failure.query,
      failure.expectedOutcome,
      failure.classification,
      failure.topEvidence,
      failure.reproCommand ?? "repro unavailable"
    ])
  );
}

export function renderCompetitorComparison(audit) {
  const targets = audit.targets.map(target => target.id);
  const rows = [];
  for (const caseId of audit.sample) {
    const resultByTarget = new Map(
      audit.results
        .filter(result => result.caseId === caseId)
        .map(result => [result.targetId, result])
    );
    rows.push([
      caseId,
      ...targets.map(targetId => {
        const result = resultByTarget.get(targetId);
        return result ? `${result.verdict}/${result.classification}` : "missing";
      })
    ]);
  }
  return renderMarkdownTable(["Case", ...targets], rows);
}

export function buildIssueCollection(audit) {
  const failures = actionableIDocsFailures(audit.results);
  if (failures.length === 0) {
    return { action: "none", actionableFailures: [] };
  }
  const fingerprint = computeFailureFingerprint(failures.map(failure => ({
    caseId: failure.caseId,
    expectedOutcome: failure.expectedOutcome,
    classification: failure.classification
  })));
  return { action: "pending", fingerprint, actionableFailures: failures };
}

export function renderIssueBody(audit, fingerprint) {
  const failures = actionableIDocsFailures(audit.results);
  const competitorVersions = audit.targets
    .filter(target => target.kind === "competitor")
    .map(target => `- ${target.displayName}: ${target.resolvedVersion ?? "unknown"}`)
    .join("\n");
  return [
    "# Search Quality Race detected iDocs golden-truth failures",
    "",
    `Fingerprint: ${fingerprint}`,
    "",
    `CI run URL: ${audit.runUrl ?? "unavailable"}`,
    `Seed/sample-size: ${audit.seed}/${audit.sampleSize}`,
    `Simulated failure: ${audit.simulatedFailure ? "yes - automation validation path, not a product regression" : "no"}`,
    `Artifact path: ${audit.artifacts?.json ?? "random-search-audit.json"}`,
    "",
    "## Failing cases",
    "",
    renderMarkdownTable(
      ["Case", "Query", "Expected", "Classification", "Repro"],
      failures.map(failure => [
        failure.caseId,
        failure.query,
        failure.expectedOutcome,
        failure.classification,
        failure.reproCommand ?? "repro unavailable"
      ])
    ),
    "",
    "## iDocs diagnostics",
    "",
    `- Local docs diagnostic: ${audit.localDocsDiagnostic?.reason ?? "unknown"}`,
    `- Remote-only: ${audit.remoteOnly ? "yes" : "no"}`,
    "",
    "## Competitor versions",
    "",
    competitorVersions || "No competitor versions recorded.",
    ""
  ].join("\n");
}

export function renderIssueComment(audit, fingerprint) {
  return [
    `Search Quality Race saw the same fingerprint again: ${fingerprint}`,
    "",
    `CI run URL: ${audit.runUrl ?? "unavailable"}`,
    `Simulated failure: ${audit.simulatedFailure ? "yes - automation validation path, not a product regression" : "no"}`,
    `Report: ${audit.artifacts?.markdown ?? "random-search-audit.md"}`,
    `Artifact: ${audit.artifacts?.json ?? "random-search-audit.json"}`
  ].join("\n");
}

export function redactSensitiveValues(value) {
  let output = String(value ?? "");
  output = output.replace(/(GITHUB_TOKEN|NODE_AUTH_TOKEN|NPM_TOKEN|GH_TOKEN)=\S+/g, "$1=[REDACTED]");
  output = output.replace(/\b(ghp|github_pat|npm)_[A-Za-z0-9_]+/g, "[REDACTED]");
  return output;
}

export function redactRawEvidence(value) {
  if (value == null) return value;
  if (typeof value === "string") return redactSensitiveValues(value);
  if (typeof value === "number" || typeof value === "boolean") return value;
  if (Array.isArray(value)) return value.map(item => redactRawEvidence(item));
  if (typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, nested]) => [key, redactRawEvidence(nested)])
    );
  }
  return redactSensitiveValues(value);
}

export function renderMarkdownTable(headers, rows) {
  const header = `| ${headers.join(" | ")} |`;
  const separator = `| ${headers.map(() => "---").join(" | ")} |`;
  const body = rows.map(row => `| ${row.map(cell => String(cell ?? "").replaceAll("\n", " ")).join(" | ")} |`);
  return [header, separator, ...body].join("\n");
}

export function topEvidence(rawResult) {
  const normalized = normalizeRawResult(rawResult);
  const text = normalized.text || normalized.path || normalized.error || "";
  return redactSensitiveValues(text).slice(0, 300);
}

function buildClassification(classification, verdict, normalized) {
  return {
    classification,
    verdict,
    topEvidence: topEvidence(normalized),
    raw: normalized
  };
}

function normalizeRawResult(rawResult) {
  const result = rawResult ?? {};
  const results = Array.isArray(result.results) ? result.results : null;
  const first = results?.[0] ?? result;
  const path = first.path ?? first.id ?? first.url ?? null;
  const text = first.text ?? first.title ?? first.snippet ?? result.stdout ?? result.stderr ?? "";
  return {
    path,
    text,
    error: result.error ?? first.error ?? null,
    networkError: result.networkError === true || /ECONN|timeout|network/i.test(String(result.error ?? "")),
    unsupported: result.unsupported === true || /unsupported/i.test(String(result.error ?? "")),
    empty: result.empty === true || (results != null && results.length === 0) || (!path && !text && !result.error)
  };
}

function isModuleOnlyPath(path, expectedFramework) {
  if (!path || !expectedFramework) return false;
  const normalized = path.toLowerCase();
  return normalized === `/documentation/${expectedFramework}`;
}

function normalizePath(path) {
  return String(path ?? "").trim().replace(/^https:\/\/developer\.apple\.com/, "").replace(/\/$/, "").toLowerCase();
}

function competitorBinName(targetId) {
  if (targetId === "apple-docs-mcp") return "apple-docs-mcp";
  if (targetId === "apple-doc-mcp") return "apple-doc-mcp-server";
  if (targetId === "sosumi") return "sosumi";
  return targetId;
}

function seedToNumber(seed) {
  if (Number.isFinite(Number(seed))) {
    return Number(seed) >>> 0;
  }
  return crypto.createHash("sha256").update(String(seed)).digest().readUInt32LE(0);
}

function mulberry32(seed) {
  return function next() {
    let t = seed += 0x6D2B79F5;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffle(items, rng) {
  const output = [...items];
  for (let index = output.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(rng() * (index + 1));
    [output[index], output[swapIndex]] = [output[swapIndex], output[index]];
  }
  return output;
}
