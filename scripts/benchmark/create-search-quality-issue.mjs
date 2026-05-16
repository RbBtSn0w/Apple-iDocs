#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import {
  actionableIDocsFailures,
  buildIssueCollection,
  renderIssueBody,
  renderIssueComment
} from "./search-quality-lib.mjs";

const args = parseArgs(process.argv.slice(2));
const input = args.get("input");
const dryRun = args.has("dry-run");
const printBody = args.has("print-body");

if (!input) {
  process.stderr.write("--input is required\n");
  process.exit(2);
}

const audit = JSON.parse(await readFile(input, "utf8"));
const collection = buildIssueCollection(audit);
if (collection.action === "none") {
  process.stdout.write(`${JSON.stringify({ action: "none" })}\n`);
  process.exit(0);
}

const fingerprint = collection.fingerprint;
const existingIssue = await findExistingIssue(fingerprint, args.get("mock-existing-issues"));
const body = existingIssue
  ? renderIssueComment(audit, fingerprint)
  : renderIssueBody(audit, fingerprint);

if (printBody) {
  process.stdout.write(body);
  process.exit(0);
}

if (dryRun) {
  process.stdout.write(`${JSON.stringify({
    action: existingIssue ? "commented" : "created",
    fingerprint,
    issueNumber: existingIssue?.number ?? null,
    actionableFailureCount: actionableIDocsFailures(audit.results).length
  })}\n`);
  process.exit(0);
}

if (existingIssue) {
  const comment = spawnSync("gh", ["issue", "comment", String(existingIssue.number), "--body", body], { encoding: "utf8" });
  if (comment.status !== 0) {
    process.stderr.write(comment.stderr || comment.stdout);
    process.exit(2);
  }
  process.stdout.write(`${JSON.stringify({ action: "commented", fingerprint, issueNumber: existingIssue.number })}\n`);
  process.exit(0);
}

const labels = ["search-quality", "automated", "benchmark"];
const create = spawnSync("gh", ["issue", "create", "--title", `Search Quality Race failures ${fingerprint}`, "--body", body, "--label", labels.join(",")], { encoding: "utf8" });
if (create.status !== 0) {
  const fallback = spawnSync("gh", ["issue", "create", "--title", `Search Quality Race failures ${fingerprint}`, "--body", body], { encoding: "utf8" });
  if (fallback.status !== 0) {
    process.stderr.write(fallback.stderr || fallback.stdout);
    process.exit(2);
  }
  process.stdout.write(`${JSON.stringify({ action: "created", fingerprint, issueUrl: fallback.stdout.trim(), labelsApplied: [] })}\n`);
  process.exit(0);
}
process.stdout.write(`${JSON.stringify({ action: "created", fingerprint, issueUrl: create.stdout.trim(), labelsApplied: labels })}\n`);

async function findExistingIssue(fingerprint, mockIssuesPath) {
  if (mockIssuesPath) {
    const issues = JSON.parse(await readFile(mockIssuesPath, "utf8"));
    return issues.find(issue => `${issue.body ?? ""}\n${issue.title ?? ""}`.includes(fingerprint)) ?? null;
  }
  if (!fingerprint) return null;
  const list = spawnSync("gh", ["issue", "list", "--state", "open", "--json", "number,title,body", "--limit", "100"], { encoding: "utf8" });
  if (list.status !== 0) return null;
  try {
    return JSON.parse(list.stdout).find(issue => `${issue.body ?? ""}\n${issue.title ?? ""}`.includes(fingerprint)) ?? null;
  } catch {
    return null;
  }
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
