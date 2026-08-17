#!/usr/bin/env node
"use strict";

const path = require("node:path");
const { spawnSync } = require("node:child_process");

require("../tintin-lsp/test/protocol.test.js");

const wrapper = path.resolve(__dirname, "../tools/.local/bin/tintin-lsp");
const initialize = JSON.stringify({
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: {
    capabilities: {},
  },
});
const payload = Buffer.from(`Content-Length: ${Buffer.byteLength(initialize, "utf8")}\r\n\r\n${initialize}`, "utf8");
const result = spawnSync(wrapper, {
  input: payload,
  encoding: "utf8",
  timeout: 5000,
});

if (result.error) {
  throw result.error;
}

if (result.status !== 0) {
  throw new Error(result.stderr || `tintin-lsp wrapper exited with ${result.status}`);
}

if (!result.stdout.includes('"name":"tintin-lsp"')) {
  throw new Error("tintin-lsp wrapper smoke test did not receive initialize response");
}
