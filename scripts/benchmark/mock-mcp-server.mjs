#!/usr/bin/env node

import readline from "node:readline";

const mode = process.argv[2] ?? "success";
const rl = readline.createInterface({
  input: process.stdin,
  terminal: false
});

function write(message) {
  process.stdout.write(JSON.stringify(message) + "\n");
}

function toolContent(text) {
  return {
    content: [
      {
        type: "text",
        text
      }
    ]
  };
}

rl.on("line", (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }

  if (message.method === "initialize" && message.id) {
    write({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "mock-benchmark-server", version: "0.1.0" }
      }
    });
    return;
  }

  if (message.method === "tools/list" && message.id) {
    write({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        tools: [
          {
            name: "search_symbols",
            description: "Mock search tool",
            inputSchema: { type: "object", properties: {} }
          }
        ]
      }
    });
    return;
  }

  if (message.method === "tools/call" && message.id) {
    const text = mode == "failure-like"
      ? "# Search Cannot Proceed - No Technology Selected"
      : "# View\n\nA protocol that provides a view.";
    write({
      jsonrpc: "2.0",
      id: message.id,
      result: toolContent(text)
    });
  }
});
