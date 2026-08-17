#!/usr/bin/env node
"use strict";

const { spawnSync } = require("node:child_process");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const server = path.join(repoRoot, "tools/.local/bin/tintin-lsp");

function request(message) {
  const body = JSON.stringify(message);
  return `Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`;
}

function runLsp(messages) {
  const result = spawnSync(server, {
    cwd: repoRoot,
    input: messages.map(request).join(""),
    timeout: 5000,
  });

  assert(
    result.status === 0,
    [
      result.error ? result.error.message : `tintin-lsp exited with ${result.status}`,
      result.stdout && result.stdout.length ? `stdout:\n${result.stdout.toString("utf8")}` : "",
      result.stderr && result.stderr.length ? `stderr:\n${result.stderr.toString("utf8")}` : "",
    ]
      .filter(Boolean)
      .join("\n")
  );

  const responses = [];
  const output = result.stdout;
  const separator = Buffer.from("\r\n\r\n", "utf8");
  let index = 0;
  while (index < output.length) {
    const headerEnd = output.indexOf(separator, index);
    if (headerEnd === -1) {
      assert(output.slice(index).toString("utf8").trim() === "", `unexpected unframed stdout near offset ${index}`);
      break;
    }

    const match = output.slice(index, headerEnd).toString("utf8").match(/Content-Length:\s*(\d+)/i);
    assert(match, `missing Content-Length near offset ${index}`);

    const bodyStart = headerEnd + 4;
    const bodyEnd = bodyStart + Number(match[1]);
    responses.push(JSON.parse(output.slice(bodyStart, bodyEnd).toString("utf8")));
    index = bodyEnd;
  }

  return responses;
}

function initialize() {
  return { jsonrpc: "2.0", id: 1, method: "initialize", params: { capabilities: {} } };
}

function open(uri, text) {
  return {
    jsonrpc: "2.0",
    method: "textDocument/didOpen",
    params: {
      textDocument: {
        uri,
        languageId: "tintin",
        version: 1,
        text,
      },
    },
  };
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function byId(responses, id) {
  return responses.find((response) => response.id === id);
}

function diagnostics(responses) {
  const publication = responses.find((response) => response.method === "textDocument/publishDiagnostics");
  return publication ? publication.params.diagnostics : [];
}

function testCompletionItemsArePlainText() {
  const uri = "file:///tmp/tintin-completion.tt++";
  const responses = runLsp([
    initialize(),
    open(uri, "#al"),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "textDocument/completion",
      params: { textDocument: { uri }, position: { line: 0, character: 3 } },
    },
  ]);

  const completion = byId(responses, 2).result.find((item) => item.label === "#alias");
  assert(completion, "expected #alias completion");
  assert(completion.kind === 14, `expected #alias to be Keyword kind 14, got ${completion.kind}`);
  assert(completion.insertText === "#alias", `expected plain #alias insertText, got ${completion.insertText}`);
  assert(completion.insertTextFormat === 1, `expected plain-text insert format, got ${completion.insertTextFormat}`);
  assert(!completion.snippetText, "completion should not include snippetText");
}

function testParserDiagnosticsAndRename() {
  const uri = "file:///tmp/tintin-rename.tt++";
  const text = [
    "#variable {hp} {10}",
    "#alias {heal} {#notacommand {x};#send $hp;#nop {$hp should stay}}",
    "/* $hp should stay */",
    "",
  ].join("\n");

  const responses = runLsp([
    initialize(),
    open(uri, text),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "textDocument/rename",
      params: { textDocument: { uri }, position: { line: 0, character: 12 }, newName: "health" },
    },
  ]);

  assert(
    diagnostics(responses).some((item) => item.message.includes("#notacommand")),
    "expected nested unknown-command diagnostic"
  );
  const edits = byId(responses, 2).result.changes[uri];
  assert(edits.length === 2, `expected definition and real reference rename edits only, got ${edits.length}`);
  assert(edits.every((edit) => edit.newText === "health"), "rename edit text mismatch");
}

function testFormatterPreservesMultilineValues() {
  const uri = "file:///tmp/tintin-format.tt++";
  const text = "#variable {msg} {hello   \n    café};#alias {show} {#showme $msg}\n";
  const responses = runLsp([
    initialize(),
    open(uri, text),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "textDocument/formatting",
      params: { textDocument: { uri }, options: { tabSize: 999999 } },
    },
  ]);

  const formatted = byId(responses, 2).result[0].newText;
  assert(
    formatted === "#variable {msg} {hello   \n    café}\n#alias {show} {#showme $msg}\n",
    `unexpected formatted output: ${JSON.stringify(formatted)}`
  );
}

function testInvalidParamsKeepRequestId() {
  const responses = runLsp([
    initialize(),
    { jsonrpc: "2.0", id: 2, method: "textDocument/completion", params: {} },
    { jsonrpc: "2.0", id: 3, method: "textDocument/hover", params: { textDocument: { uri: "file:///tmp/a.tt++" } } },
    { jsonrpc: "2.0", id: 4, method: "textDocument/formatting", params: { textDocument: { uri: "file:///tmp/a.tt++" } } },
    {
      jsonrpc: "2.0",
      id: 5,
      method: "textDocument/completion",
      params: { textDocument: { uri: "file:///tmp/a.tt++" }, position: { line: -1, character: 0 } },
    },
    {
      jsonrpc: "2.0",
      id: 6,
      method: "textDocument/completion",
      params: { textDocument: { uri: "file:///tmp/a.tt++" }, position: { line: 0, character: -1 } },
    },
  ]);

  for (const id of [2, 3, 4, 5, 6]) {
    const response = byId(responses, id);
    assert(response, `expected error response for request ${id}`);
    assert(response.error && response.error.code === -32602, `expected Invalid params for request ${id}`);
  }
}

function testRenameNameValidation() {
  const uri = "file:///tmp/tintin-invalid-rename.tt++";
  const text = "#variable {hp} {10}\n#send $hp\n";
  const malformedNames = [undefined, null, 42];

  for (const [index, newName] of malformedNames.entries()) {
    const params = { textDocument: { uri }, position: { line: 0, character: 12 } };
    if (newName !== undefined) {
      params.newName = newName;
    }

    const responses = runLsp([
      initialize(),
      open(uri, text),
      { jsonrpc: "2.0", id: 2 + index, method: "textDocument/rename", params },
    ]);

    const response = byId(responses, 2 + index);
    assert(response.error && response.error.code === -32602, `expected Invalid params for ${String(newName)}`);
  }

  const missingSymbolResponses = runLsp([
    initialize(),
    open(uri, text),
    {
      jsonrpc: "2.0",
      id: 10,
      method: "textDocument/rename",
      params: { textDocument: { uri }, position: { line: 1, character: 0 }, newName: null },
    },
  ]);
  assert(
    byId(missingSymbolResponses, 10).error && byId(missingSymbolResponses, 10).error.code === -32602,
    "malformed newName should return Invalid params before symbol lookup"
  );

  for (const newName of ["", "bad-name"]) {
    const responses = runLsp([
      initialize(),
      open(uri, text),
      {
        jsonrpc: "2.0",
        id: 2,
        method: "textDocument/rename",
        params: { textDocument: { uri }, position: { line: 0, character: 12 }, newName },
      },
    ]);

    assert(byId(responses, 2).result === null, `expected null rename result for ${String(newName)}`);
  }
}

function testKnownCommandsAndEmptyFormatting() {
  const uri = "file:///tmp/tintin-daemon.tt++";
  const emptyUri = "file:///tmp/tintin-empty.tt++";

  let responses = runLsp([initialize(), open(uri, "#daemon list\n")]);
  assert(diagnostics(responses).length === 0, "#daemon should not produce an unknown-command diagnostic");

  responses = runLsp([
    initialize(),
    open(emptyUri, ""),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "textDocument/formatting",
      params: { textDocument: { uri: emptyUri }, options: { tabSize: 2 } },
    },
  ]);
  assert(Array.isArray(byId(responses, 2).result), "expected formatting result array");
  assert(byId(responses, 2).result.length === 0, "empty document should not produce formatting edits");
}

function testInitializeNotificationDoesNotRespond() {
  const responses = runLsp([{ jsonrpc: "2.0", method: "initialize", params: { capabilities: {} } }]);
  assert(responses.length === 0, "initialize notification should not produce a response");
}

function testJsonRpcEnvelopeValidation() {
  let responses = runLsp([{ jsonrpc: "2.0", id: 2, method: 42, params: {} }]);
  assert(byId(responses, 2).error.code === -32600, "non-string method should return Invalid Request");

  responses = runLsp([{ jsonrpc: "2.0", id: { bad: true }, method: "initialize", params: { capabilities: {} } }]);
  assert(responses.length === 1, "invalid id request should produce one error response");
  assert(responses[0].id === null, "invalid id shape should respond with null id");
  assert(responses[0].error.code === -32600, "invalid id shape should return Invalid Request");

  responses = runLsp([{ jsonrpc: "1.0", id: 2, method: "initialize", params: { capabilities: {} } }]);
  assert(byId(responses, 2).error.code === -32600, "wrong jsonrpc version should return Invalid Request");

  responses = runLsp([{ jsonrpc: "2.0", method: "shutdown" }]);
  assert(responses.length === 0, "shutdown notification should not produce a response");
}

const tests = [
  testCompletionItemsArePlainText,
  testParserDiagnosticsAndRename,
  testFormatterPreservesMultilineValues,
  testInvalidParamsKeepRequestId,
  testRenameNameValidation,
  testKnownCommandsAndEmptyFormatting,
  testInitializeNotificationDoesNotRespond,
  testJsonRpcEnvelopeValidation,
];

for (const test of tests) {
  test();
}

console.log(`ok: ${tests.length} tintin-lsp protocol tests passed`);
