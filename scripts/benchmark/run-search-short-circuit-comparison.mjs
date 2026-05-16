#!/usr/bin/env node
import { spawn } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const repoRoot = process.cwd();
const defaultRunId = `run-${new Date().toISOString().replace(/[-:]/g, "").replace(/\..+/, "Z")}-search-short-circuit`;
const runId = readArg("--run-id") ?? defaultRunId;
const outputDir = path.join(repoRoot, "specs/008-mcp-service-benchmark/artifacts/results", runId);

const cases = [
  {
    id: "swiftui-navigation-split-view",
    query: "SwiftUI NavigationSplitView",
    expectedScope: "symbol",
    expectedPath: "/documentation/swiftui/navigationsplitview",
    expectedTerms: ["NavigationSplitView"],
    moduleExactPaths: ["/documentation/SwiftUI", "/documentation/swiftui"],
    appleDocMcpTechnology: "SwiftUI",
    appleDocMcpQuery: "NavigationSplitView"
  },
  {
    id: "nswindow-toolbar-style",
    query: "NSWindow toolbarStyle",
    expectedScope: "symbol",
    expectedPath: "/documentation/appkit/nswindow/toolbarstyle",
    expectedTerms: ["toolbarStyle"],
    moduleExactPaths: ["/documentation/NSWindow", "/documentation/nswindow"],
    appleDocMcpTechnology: "AppKit",
    appleDocMcpQuery: "NSWindow toolbarStyle"
  },
  {
    id: "navigation-split-view",
    query: "NavigationSplitView",
    expectedScope: "symbol",
    expectedPath: "/documentation/swiftui/navigationsplitview",
    expectedTerms: ["NavigationSplitView"],
    moduleExactPaths: ["/documentation/NavigationSplitView"],
    appleDocMcpTechnology: "SwiftUI",
    appleDocMcpQuery: "NavigationSplitView"
  },
  {
    id: "ns-split-view-controller",
    query: "NSSplitViewController",
    expectedScope: "symbol",
    expectedPath: "/documentation/appkit/nssplitviewcontroller",
    expectedTerms: ["NSSplitViewController"],
    moduleExactPaths: ["/documentation/NSSplitViewController"],
    appleDocMcpTechnology: "AppKit",
    appleDocMcpQuery: "NSSplitViewController"
  },
  {
    id: "swiftui-module-control",
    query: "SwiftUI",
    expectedScope: "module",
    expectedPath: "/documentation/swiftui",
    expectedTerms: ["SwiftUI"],
    moduleExactPaths: ["/documentation/SwiftUI", "/documentation/swiftui"],
    appleDocMcpTechnology: "SwiftUI",
    appleDocMcpQuery: "SwiftUI"
  }
];

const targets = [
  { id: "idocs", runner: runIDocs },
  { id: "corrival/apple-docs-mcp", runner: runAppleDocsMCP },
  { id: "corrival/apple-doc-mcp", runner: runAppleDocMCP },
  { id: "corrival/sosumi.ai", runner: runSosumiCLI }
];

await mkdir(outputDir, { recursive: true });

const records = [];
for (const testCase of cases) {
  for (const target of targets) {
    const startedAt = Date.now();
    try {
      const result = await target.runner(testCase);
      const durationMs = Date.now() - startedAt;
      const evidenceText = extractEvidenceText(result);
      const assessment = assessResult(testCase, evidenceText, result.status ?? "success");
      records.push({
        caseId: testCase.id,
        query: testCase.query,
        targetId: target.id,
        durationMs,
        ...assessment,
        raw: truncateRaw(result, 8_000)
      });
    } catch (error) {
      records.push({
        caseId: testCase.id,
        query: testCase.query,
        targetId: target.id,
        durationMs: Date.now() - startedAt,
        classification: "error",
        symbolHit: false,
        moduleOnly: false,
        empty: false,
        diagnostic: String(error.message ?? error),
        raw: { error: String(error.stack ?? error) }
      });
    }
  }
}

const summary = {
  runId,
  generatedAt: new Date().toISOString(),
  cases: cases.map(({ id, query, expectedPath }) => ({ id, query, expectedPath })),
  records
};

await writeFile(
  path.join(outputDir, "search-short-circuit-comparison.json"),
  `${JSON.stringify(summary, null, 2)}\n`
);
await writeFile(path.join(outputDir, "report.md"), renderReport(summary));

process.stdout.write(`${JSON.stringify({ status: "success", runId, outputDir }, null, 2)}\n`);

function readArg(name) {
  const index = process.argv.indexOf(name);
  if (index === -1) return null;
  return process.argv[index + 1] ?? null;
}

async function runIDocs(testCase) {
  const localBinary = process.env.IDOCS_LOCAL_BINARY;
  const command = localBinary || "./scripts/tuist-silent.sh";
  const args = localBinary
    ? ["search", testCase.query, "--json"]
    : ["run", "idocs", "search", testCase.query, "--json"];
  const result = await runProcess(command, args, { timeoutMs: 120_000 });
  return parseProcessResult(result);
}

async function runSosumiCLI(testCase) {
  const result = await runProcess(
    "node",
    ["corrival/sosumi.ai/bin/sosumi.mjs", "search", testCase.query, "--json"],
    { timeoutMs: 60_000 }
  );
  return parseProcessResult(result);
}

async function runAppleDocsMCP(testCase) {
  return callMCPSequence(
    "node",
    ["corrival/apple-docs-mcp/dist/index.js"],
    [
      {
        name: "search_apple_docs",
        arguments: { query: testCase.query, type: "all" }
      }
    ]
  );
}

async function runAppleDocMCP(testCase) {
  return callMCPSequence(
    "node",
    ["corrival/apple-doc-mcp/dist/index.js"],
    [
      {
        name: "choose_technology",
        arguments: { name: testCase.appleDocMcpTechnology }
      },
      {
        name: "search_symbols",
        arguments: { query: testCase.appleDocMcpQuery, maxResults: 5 }
      }
    ]
  );
}

function runProcess(command, args, { timeoutMs }) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: repoRoot, shell: false });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill();
      reject(new Error(`timeout after ${timeoutMs}ms: ${command} ${args.join(" ")}`));
    }, timeoutMs);

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", chunk => {
      stdout += chunk;
    });
    child.stderr.on("data", chunk => {
      stderr += chunk;
    });
    child.on("error", error => {
      clearTimeout(timer);
      reject(error);
    });
    child.on("close", code => {
      clearTimeout(timer);
      resolve({ status: code === 0 ? "success" : "failure", code, stdout, stderr });
    });
  });
}

function parseProcessResult(result) {
  const parsed = parseJSON(result.stdout);
  return {
    status: result.status,
    code: result.code,
    stdout: result.stdout,
    stderr: result.stderr,
    parsed
  };
}

async function callMCPSequence(command, args, calls) {
  const child = spawn(command, args, { cwd: repoRoot, shell: false, stdio: ["pipe", "pipe", "pipe"] });
  let stderr = "";
  const pending = new Map();
  const callResults = [];

  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", chunk => {
    stderr += chunk;
  });
  child.stdout.on("data", chunk => {
    for (const line of chunk.split("\n").filter(Boolean)) {
      const message = parseJSON(line);
      if (message?.id && pending.has(message.id)) {
        pending.get(message.id).resolve(message);
        pending.delete(message.id);
      }
    }
  });

  let nextId = 0;
  function request(method, params, timeoutMs = 60_000) {
    nextId += 1;
    const id = nextId;
    child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`timeout for MCP method ${method}`));
      }, timeoutMs);
      pending.set(id, {
        resolve: value => {
          clearTimeout(timer);
          resolve(value);
        }
      });
    });
  }

  try {
    await request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "search-short-circuit-comparison", version: "0.1.0" }
    });
    child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized", params: {} })}\n`);
    await request("tools/list", {});

    for (const call of calls) {
      const response = await request("tools/call", {
        name: call.name,
        arguments: call.arguments
      });
      callResults.push({ tool: call.name, response });
    }

    return { status: "success", calls: callResults, stderr };
  } finally {
    child.kill();
  }
}

function parseJSON(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function extractEvidenceText(value) {
  const texts = [];
  collectText(value, texts);
  return texts.join("\n");
}

function collectText(value, texts) {
  if (value == null) return;
  if (typeof value === "string") {
    texts.push(value);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectText(item, texts);
    return;
  }
  if (typeof value === "object") {
    for (const [key, nested] of Object.entries(value)) {
      if ((key === "text" || key === "stdout" || key === "stderr") && typeof nested === "string") {
        texts.push(nested);
      }
      collectText(nested, texts);
    }
  }
}

function assessResult(testCase, text, status) {
  const lower = text.toLowerCase();
  const empty = /\bno results found\b/.test(lower)
    || /"results"\s*:\s*\[\s*\]/.test(lower);
  const expectedPathHit = lower.includes(testCase.expectedPath.toLowerCase());
  const moduleHit = testCase.expectedScope === "module"
    && testCase.moduleExactPaths.some(item => lower.includes(item.toLowerCase()))
    && !empty;
  const expectedTermHit = !empty && testCase.expectedTerms.some(term => lower.includes(term.toLowerCase()));
  const symbolHit = testCase.expectedScope === "symbol" && (expectedPathHit || expectedTermHit);
  const moduleOnly = !symbolHit && testCase.moduleExactPaths.some(item => lower.includes(item.toLowerCase()));
  const moduleFallbackDistinguished = moduleOnly && (
    lower.includes("match_scope")
    || lower.includes("scope: module")
    || lower.includes("module-level")
  );

  let classification = "other";
  if (status !== "success") {
    classification = "error";
  } else if (moduleHit) {
    classification = "module_hit";
  } else if (symbolHit) {
    classification = "symbol_hit";
  } else if (moduleFallbackDistinguished) {
    classification = "module_fallback_distinguished";
  } else if (moduleOnly) {
    classification = "module_only_unqualified";
  } else if (empty) {
    classification = "empty";
  }

  return {
    classification,
    symbolHit,
    moduleOnly,
    empty,
    diagnostic: diagnosticFor(classification)
  };
}

function diagnosticFor(classification) {
  switch (classification) {
    case "symbol_hit":
      return "Returned or exposed the expected symbol-level evidence.";
    case "module_hit":
      return "Returned or exposed the expected module-level control result.";
    case "module_fallback_distinguished":
      return "Returned only a module/type fallback but labeled it as fallback/module scoped.";
    case "module_only_unqualified":
      return "Returned a module/type result without enough evidence that it satisfied a symbol/member query.";
    case "empty":
      return "Returned no search result for a known documentation page.";
    case "error":
      return "The target failed or timed out.";
    default:
      return "Returned output that did not match expected symbol, module fallback, or empty-result patterns.";
  }
}

function truncateRaw(value, maxLength) {
  const json = JSON.stringify(value, null, 2);
  if (json.length <= maxLength) return value;
  return { truncated: true, firstChars: json.slice(0, maxLength) };
}

function renderReport(summary) {
  const lines = [
    "# Search Short-Circuit Comparison",
    "",
    `Run: \`${summary.runId}\``,
    `Generated: ${summary.generatedAt}`,
    "",
    "## Summary",
    "",
    "| Query | Target | Classification | Diagnostic |",
    "| --- | --- | --- | --- |"
  ];

  for (const record of summary.records) {
    lines.push(`| ${escapeCell(record.query)} | \`${record.targetId}\` | \`${record.classification}\` | ${escapeCell(record.diagnostic)} |`);
  }

  lines.push(
    "",
    "## Classification Legend",
    "",
    "- `symbol_hit`: the target returned or exposed the expected symbol/member-level result.",
    "- `module_hit`: the target returned or exposed the expected module-level control result.",
    "- `module_fallback_distinguished`: the target returned only a module/type fallback but clearly labeled it.",
    "- `module_only_unqualified`: the target returned only a module/type result without clear fallback semantics.",
    "- `empty`: the target returned no result for the known documentation page.",
    "- `error`: the target failed, timed out, or could not complete the workflow.",
    "",
    "## Raw Evidence",
    "",
    "See `search-short-circuit-comparison.json` in this directory."
  );

  return `${lines.join("\n")}\n`;
}

function escapeCell(value) {
  return String(value).replace(/\|/g, "\\|").replace(/\n/g, "<br>");
}
