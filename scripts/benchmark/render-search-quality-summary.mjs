#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { renderAuditMarkdown } from "./search-quality-lib.mjs";

const args = parseArgs(process.argv.slice(2));
const input = args.get("input");
if (!input) {
  process.stderr.write("--input is required\n");
  process.exit(2);
}
const output = args.get("output");
const audit = JSON.parse(await readFile(input, "utf8"));
const summary = renderAuditMarkdown(audit);

if (output) {
  await writeFile(output, summary);
} else {
  process.stdout.write(summary);
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
