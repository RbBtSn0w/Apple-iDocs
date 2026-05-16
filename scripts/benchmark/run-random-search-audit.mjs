#!/usr/bin/env node
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import {
  DEFAULT_TARGETS,
  actionableIDocsFailures,
  buildIssueCollection,
  classifyProductResult,
  createSeededSampler,
  redactRawEvidence,
  renderAuditMarkdown,
  targetMetadataFromVersions,
  topEvidence
} from "./search-quality-lib.mjs";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));

if (args.has("mock-infra-failure")) {
  process.stderr.write("mock infrastructure failure requested\n");
  process.exit(2);
}

const seed = Number(args.get("seed") ?? 1);
const sampleSize = Number(args.get("sample-size") ?? 40);
const poolPath = args.get("pool") ?? "specs/008-mcp-service-benchmark/fixtures/search-audit-pool.json";
const outputDir = args.get("output-dir") ?? "artifacts/search-quality-race";
const mockTargetsPath = args.get("mock-targets");
const mockFailure = args.has("mock-failure") || args.get("mock-failure") === "true";
const idocsBinary = args.get("idocs-binary") ?? process.env.IDOCS_LOCAL_BINARY ?? "idocs";
const inferredRunUrl = process.env.GITHUB_SERVER_URL && process.env.GITHUB_REPOSITORY && process.env.GITHUB_RUN_ID
  ? `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
  : "local";
const runUrl = args.get("run-url") ?? inferredRunUrl;

const pool = JSON.parse(await readFile(path.resolve(repoRoot, poolPath), "utf8"));
const sample = createSeededSampler(pool, { seed, sampleSize });
const mockTargets = mockTargetsPath
  ? JSON.parse(await readFile(path.resolve(repoRoot, mockTargetsPath), "utf8"))
  : null;

const versionMetadata = mockTargets
  ? { versions: mockTargets.versions ?? {}, installDir: null }
  : await readVersionMetadata(args.get("versions-file"));
const targets = targetMetadataFromVersions(versionMetadata.versions, { idocsBinary, installDir: versionMetadata.installDir });
const results = [];

let injectedFailure = false;
for (const testCase of sample) {
  for (const target of targets) {
    const raw = await runTarget({ target, testCase, mockTargets, idocsBinary });
    if (mockFailure && target.id === "idocs" && testCase.expectedOutcome !== "invalid_no_result" && !injectedFailure) {
      raw.path = "/documentation/swiftui";
      raw.text = "SwiftUI framework";
      injectedFailure = true;
    }
    const assessment = classifyProductResult(testCase, raw);
    results.push({
      caseId: testCase.id,
      targetId: target.id,
      framework: testCase.framework,
      queryShape: testCase.queryShape,
      query: testCase.query,
      expectedOutcome: testCase.expectedOutcome,
      classification: assessment.classification,
      verdict: assessment.verdict,
      topEvidence: assessment.topEvidence || topEvidence(raw),
      rawEvidence: redactRawEvidence(raw),
      diagnostics: redactRawEvidence(raw.diagnostics ?? null),
      reproCommand: target.id === "idocs" && assessment.verdict === "fail"
        ? `IDOCS_XCODE_DOC_CACHE_PATH=/tmp/idocs-nonexistent-doc-cache ${idocsBinary} search ${JSON.stringify(testCase.query)} --json`
        : null
    });
  }
}

const audit = {
  schemaVersion: 1,
  runId: args.get("run-id") ?? `search-quality-${new Date().toISOString().replace(/[-:.]/g, "")}`,
  generatedAt: new Date().toISOString(),
  seed,
  sampleSize,
  actualSampleSize: sample.length,
  commitSha: process.env.GITHUB_SHA ?? gitSha(),
  idocsBinary,
  runUrl,
  remoteOnly: true,
  simulatedFailure: mockFailure,
  localDocsDiagnostic: {
    reason: "local_docs_unavailable",
    hint: "CI sets IDOCS_XCODE_DOC_CACHE_PATH to a nonexistent path; local Xcode comparison excluded."
  },
  targets,
  sample: sample.map(testCase => testCase.id),
  cases: sample,
  results,
  issueCollection: {},
  artifacts: {
    json: "random-search-audit.json",
    markdown: "random-search-audit.md"
  }
};
audit.issueCollection = buildIssueCollection(audit);
if (audit.issueCollection.fingerprint) {
  audit.issueCollection.actionableFailureCount = actionableIDocsFailures(results).length;
}

await mkdir(outputDir, { recursive: true });
await writeFile(path.join(outputDir, "random-search-audit.json"), `${JSON.stringify(audit, null, 2)}\n`);
await writeFile(path.join(outputDir, "random-search-audit.md"), renderAuditMarkdown(audit));

process.stdout.write(`${JSON.stringify({ status: "completed", outputDir, qualityFailures: actionableIDocsFailures(results).length }, null, 2)}\n`);

async function runTarget({ target, testCase, mockTargets, idocsBinary }) {
  const mock = mockTargets?.results?.[testCase.id]?.[target.id];
  if (mock) return structuredClone(mock);
  if (mockTargets) return defaultMockResult(testCase);
  if (target.id === "idocs") return runIDocs(testCase, idocsBinary);
  return runCompetitor(target, testCase);
}

function defaultMockResult(testCase) {
  if (testCase.expectedOutcome === "invalid_no_result") return { results: [] };
  return {
    path: testCase.canonicalPaths?.[0] ?? "/documentation/unknown",
    text: testCase.requiredTerms?.join(" ") ?? testCase.query
  };
}

function runIDocs(testCase, idocsBinary) {
  const command = idocsBinary === "idocs" ? "./scripts/tuist-silent.sh" : idocsBinary;
  const commandArgs = idocsBinary === "idocs"
    ? ["run", "idocs", "search", testCase.query, "--json"]
    : ["search", testCase.query, "--json"];
  const result = spawnSync(command, commandArgs, {
    cwd: repoRoot,
    encoding: "utf8",
    env: {
      ...process.env,
      IDOCS_XCODE_DOC_CACHE_PATH: process.env.IDOCS_XCODE_DOC_CACHE_PATH ?? "/tmp/idocs-nonexistent-doc-cache"
    },
    timeout: 120_000
  });
  if (result.error) return { error: result.error.message, networkError: true };
  if (result.status !== 0) return { error: result.stderr || result.stdout, unsupported: false };
  try {
    const payload = JSON.parse(result.stdout);
    return {
      results: payload.results?.map(item => ({ path: item.id, text: `${item.title ?? ""} ${item.snippet ?? ""}` })) ?? [],
      diagnostics: payload.search_diagnostics
    };
  } catch {
    return { text: result.stdout, path: null };
  }
}

async function readVersionMetadata(file) {
  if (!file) return { versions: {}, installDir: null };
  try {
    const data = JSON.parse(await readFile(path.resolve(repoRoot, file), "utf8"));
    const versions = {};
    for (const [packageName, metadata] of Object.entries(data.packages ?? {})) {
      versions[packageName] = metadata.resolvedVersion;
    }
    return { versions, installDir: data.installDir ?? null };
  } catch {
    return { versions: {}, installDir: null };
  }
}

async function runCompetitor(target, testCase) {
  const missingBinary = missingCompetitorBinary(target);
  if (missingBinary) return missingBinary;

  if (target.id === "sosumi") {
    return runSosumi(target, testCase);
  }
  if (target.id === "apple-docs-mcp") {
    return runAppleDocsMCP(target, testCase);
  }
  if (target.id === "apple-doc-mcp") {
    return runAppleDocMCP(target, testCase);
  }
  return { error: `unsupported competitor target ${target.id}`, unsupported: true };
}

function missingCompetitorBinary(target) {
  if (typeof target.binaryPath !== "string" || !target.binaryPath.includes("/")) {
    return null;
  }
  if (existsSync(target.binaryPath)) {
    return null;
  }
  return { error: `competitor binary not found: ${target.binaryPath}`, networkError: true };
}

function runSosumi(target, testCase) {
  const result = spawnSync(target.binaryPath, ["search", testCase.query, "--json"], {
    cwd: repoRoot,
    encoding: "utf8",
    timeout: 120_000
  });
  if (result.error) return { error: result.error.message, networkError: true };
  if (result.status !== 0) return { error: result.stderr || result.stdout, unsupported: true };
  try {
    const payload = JSON.parse(result.stdout);
    return normalizeCompetitorPayload(payload);
  } catch {
    return evidenceFromText(result.stdout);
  }
}

async function runAppleDocsMCP(target, testCase) {
  const response = await callMCPTool(target.binaryPath, "search_apple_docs", {
    query: testCase.query,
    type: "all"
  });
  return response.error ? response : evidenceFromMCPResponse(response);
}

async function runAppleDocMCP(target, testCase) {
  const query = searchQueryForFrameworkScopedTool(testCase);
  const response = await callMCPTool(
    target.binaryPath,
    "search_symbols",
    { query, maxResults: 10 },
    [{ name: "choose_technology", arguments: { name: testCase.framework } }]
  );
  return response.error ? response : evidenceFromMCPResponse(response);
}

async function callMCPTool(command, toolName, toolArguments, beforeCalls = []) {
  const child = spawn(command, [], {
    cwd: repoRoot,
    stdio: ["pipe", "pipe", "pipe"]
  });
  let stdout = "";
  let stderr = "";
  let nextId = 1;
  const pending = new Map();
  let buffer = "";
  let settled = false;
  let spawnError = null;

  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  child.on("error", error => {
    spawnError = error;
    for (const resolve of pending.values()) {
      resolve({ error: { message: error.message } });
    }
    pending.clear();
  });
  child.stdout.on("data", chunk => {
    stdout += chunk;
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const message = JSON.parse(line);
        const resolver = pending.get(message.id);
        if (resolver) {
          pending.delete(message.id);
          resolver(message);
        }
      } catch {
        // Ignore non-protocol stdout; it is retained in raw evidence on failure.
      }
    }
  });
  child.stderr.on("data", chunk => {
    stderr += chunk;
  });

  const timeout = setTimeout(() => {
    settled = true;
    child.kill("SIGTERM");
  }, 120_000);

  function send(method, params) {
    if (spawnError) {
      return Promise.resolve({ error: { message: spawnError.message } });
    }
    const id = nextId;
    nextId += 1;
    const promise = new Promise(resolve => {
      const requestTimeout = setTimeout(() => {
        pending.delete(id);
        settled = true;
        child.kill("SIGTERM");
        resolve({ error: { message: "MCP request timed out" } });
      }, 120_000);
      pending.set(id, message => {
        clearTimeout(requestTimeout);
        resolve(message);
      });
      try {
        child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`, error => {
          if (!error) return;
          pending.delete(id);
          clearTimeout(requestTimeout);
          resolve({ error: { message: error.message } });
        });
      } catch (error) {
        pending.delete(id);
        clearTimeout(requestTimeout);
        resolve({ error: { message: error.message } });
      }
    });
    return promise;
  }

  function notify(method, params) {
    child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
  }

  try {
    if (spawnError) return { error: spawnError.message, networkError: true, stderr, stdout };
    const initializeMessage = await send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "idocs-search-quality-race", version: "0.0.0" }
    });
    if (initializeMessage.error) {
      return { error: JSON.stringify(initializeMessage.error), networkError: true, stderr, stdout };
    }
    notify("notifications/initialized", {});
    for (const call of beforeCalls) {
      const message = await send("tools/call", { name: call.name, arguments: call.arguments });
      if (message.error) {
        return { error: JSON.stringify(message.error), unsupported: true, stderr, stdout };
      }
    }
    const message = await send("tools/call", { name: toolName, arguments: toolArguments });
    if (message.error) return { error: JSON.stringify(message.error), unsupported: true, stderr, stdout };
    return message.result ?? { stdout };
  } catch (error) {
    return { error: error.message, networkError: true, stderr, stdout };
  } finally {
    clearTimeout(timeout);
    if (settled) {
      child.kill("SIGKILL");
    } else {
      child.kill("SIGTERM");
    }
  }
}

function evidenceFromMCPResponse(response) {
  const text = (response.content ?? [])
    .map(item => item.text ?? "")
    .join("\n\n");
  return evidenceFromText(text || JSON.stringify(response));
}

function evidenceFromText(text) {
  const cleaned = String(text ?? "");
  if (/Results found:\s*0|No Results Found|No results found/i.test(cleaned)) {
    return { results: [], text: cleaned };
  }
  const paths = extractDocumentationPaths(cleaned);
  if (paths.length > 0) {
    return {
      results: paths.map(item => ({ path: item, text: cleaned })),
      text: cleaned
    };
  }
  return { text: cleaned };
}

function normalizeCompetitorPayload(payload) {
  const values = Array.isArray(payload)
    ? payload
    : Array.isArray(payload.results)
      ? payload.results
      : Array.isArray(payload.items)
        ? payload.items
        : [];
  if (values.length === 0) return { results: [], rawPayload: payload };
  return {
    results: values.map(item => ({
      path: item.url ?? item.href ?? item.path ?? item.id,
      text: [item.title, item.description, item.snippet, item.text].filter(Boolean).join(" ")
    })),
    rawPayload: payload
  };
}

function extractDocumentationPaths(text) {
  const paths = new Set();
  const developerUrl = /https:\/\/developer\.apple\.com(\/documentation\/[^\s)`"<>]+)/gi;
  const plainPath = /\b(documentation\/[A-Za-z0-9_.()/%:-]+)/g;
  for (const match of text.matchAll(developerUrl)) {
    paths.add(match[1]);
  }
  for (const match of text.matchAll(plainPath)) {
    paths.add(`/${match[1]}`);
  }
  return [...paths];
}

function searchQueryForFrameworkScopedTool(testCase) {
  const framework = String(testCase.framework ?? "");
  const query = String(testCase.query ?? "");
  if (framework && query.toLowerCase().startsWith(framework.toLowerCase())) {
    return query.slice(framework.length).trim() || query;
  }
  return query;
}

function gitSha() {
  const result = spawnSync("git", ["rev-parse", "HEAD"], { cwd: repoRoot, encoding: "utf8" });
  return result.status === 0 ? result.stdout.trim() : "unknown";
}

function parseArgs(argv) {
  const parsed = new Map();
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      parsed.set(key, true);
    } else {
      parsed.set(key, next);
      index += 1;
    }
  }
  return parsed;
}
