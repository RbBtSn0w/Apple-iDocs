#!/usr/bin/env node
import { spawn } from "node:child_process";

function parseArgs() {
  const args = process.argv.slice(2);
  const result = {
    command: null,
    commandBin: null,
    commandArgs: [],
    tool: null,
    input: null,
    rejectPatterns: []
  };
  for (let i = 0; i < args.length; i += 1) {
    const k = args[i];
    if (
      k === "--command" ||
      k === "--command-bin" ||
      k === "--tool" ||
      k === "--input" ||
      k === "--reject-pattern" ||
      k === "--command-arg"
    ) {
      const v = args[i + 1];
      if (!v) throw new Error(`missing value for ${k}`);
      if (k === "--command") result.command = v;
      if (k === "--command-bin") result.commandBin = v;
      if (k === "--command-arg") result.commandArgs.push(v);
      if (k === "--tool") result.tool = v;
      if (k === "--input") result.input = v;
      if (k === "--reject-pattern") result.rejectPatterns.push(v);
      i += 1;
      continue;
    }
    throw new Error(`unknown argument: ${k}`);
  }
  if (result.command && result.commandBin) {
    throw new Error("use either --command or --command-bin/--command-arg, not both");
  }
  if (!result.command && !result.commandBin) {
    throw new Error("missing --command or --command-bin");
  }
  return result;
}

function nextId() {
  nextId.counter += 1;
  return nextId.counter;
}
nextId.counter = 0;

function collectText(value) {
  if (value == null) return [];
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) return value.flatMap(collectText);
  if (typeof value === "object") {
    return Object.entries(value).flatMap(([key, nested]) => {
      if ((key === "text" || key === "message") && typeof nested === "string") {
        return [nested];
      }
      return collectText(nested);
    });
  }
  return [];
}

function findRejectMatch(result, rejectPatterns) {
  if (!rejectPatterns.length) return null;

  const haystacks = collectText(result);
  const json = JSON.stringify(result);
  if (json) haystacks.push(json);
  const searchable = haystacks.join("\n");
  const normalizedSearchable = searchable.toLocaleLowerCase();

  for (const pattern of rejectPatterns) {
    if (normalizedSearchable.includes(pattern.toLocaleLowerCase())) {
      return { pattern, searchable };
    }
  }

  return null;
}

async function main() {
  const { command, commandBin, commandArgs, tool, input, rejectPatterns } = parseArgs();
  const [bin, ...parts] = commandBin
    ? [commandBin, ...commandArgs]
    : command.split(" ").filter(Boolean);
  const child = spawn(bin, parts, { stdio: ["pipe", "pipe", "pipe"], shell: false });

  const pending = new Map();
  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  let stderrBuffer = "";

  child.stderr.on("data", (chunk) => {
    stderrBuffer += chunk;
  });

  child.stdout.on("data", (chunk) => {
    for (const line of chunk.split("\n").filter(Boolean)) {
      try {
        const json = JSON.parse(line);
        if (json.id && pending.has(json.id)) {
          pending.get(json.id).resolve(json);
          pending.delete(json.id);
        }
      } catch {
        // ignore non-json log lines
      }
    }
  });

  function request(method, params) {
    const id = nextId();
    const payload = { jsonrpc: "2.0", id, method, params };
    child.stdin.write(JSON.stringify(payload) + "\n");
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (pending.has(id)) {
          pending.delete(id);
          reject(new Error(`timeout for ${method}`));
        }
      }, 15000);
    });
  }

  try {
    await request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "benchmark-runner", version: "0.1.0" }
    });
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized", params: {} }) + "\n");

    const listRes = await request("tools/list", {});
    const tools = listRes?.result?.tools ?? [];
    const selected =
      tool ??
      tools.find((item) => /search|find|lookup/i.test(item.name))?.name ??
      tools[0]?.name;

    if (!selected) throw new Error("no available tool");

    const callRes = await request("tools/call", {
      name: selected,
      arguments: {
        query: input,
        text: input,
        id: input,
        path: input
      }
    });

    const rejectMatch = findRejectMatch(callRes?.result ?? null, rejectPatterns);
    if (rejectMatch) {
      const response = {
        status: "failure",
        tool: selected,
        result: callRes?.result ?? null,
        error: `tool result matched reject pattern: ${rejectMatch.pattern}`,
        error_category: "invalid_input",
        error_reason: `tool result matched reject pattern '${rejectMatch.pattern}'`,
        diagnostic_hint: "Adjust the benchmark wrapper or request so required prerequisite context is supplied before scoring the target as success.",
        stderr: stderrBuffer.trim() || null
      };
      process.stdout.write(JSON.stringify(response));
      process.exitCode = 1;
      return;
    }

    const response = {
      status: "success",
      tool: selected,
      result: callRes?.result ?? null,
      stderr: stderrBuffer.trim() || null
    };
    process.stdout.write(JSON.stringify(response));
  } catch (error) {
    const response = {
      status: "failure",
      error: String(error.message || error),
      stderr: stderrBuffer.trim() || null
    };
    process.stdout.write(JSON.stringify(response));
    process.exitCode = 1;
  } finally {
    child.kill();
  }
}

main();
