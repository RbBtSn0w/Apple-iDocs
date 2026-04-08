#!/usr/bin/env node
import { spawn } from "node:child_process";

function parseArgs() {
  const args = process.argv.slice(2);
  const result = {
    command: null,
    tool: null,
    input: null
  };
  for (let i = 0; i < args.length; i += 1) {
    const k = args[i];
    const v = args[i + 1];
    if (k === "--command") result.command = v;
    if (k === "--tool") result.tool = v;
    if (k === "--input") result.input = v;
  }
  if (!result.command) throw new Error("missing --command");
  return result;
}

function nextId() {
  nextId.counter += 1;
  return nextId.counter;
}
nextId.counter = 0;

async function main() {
  const { command, tool, input } = parseArgs();
  const [bin, ...parts] = command.split(" ");
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
