#!/usr/bin/env node
"use strict";

const { spawnSync } = require("node:child_process");
const path = require("node:path");
const packageJson = require("../package.json");

const packageRoot = path.resolve(__dirname, "..");
const server = path.join(packageRoot, "bin/tintin-lsp");

function request(message) {
  const body = JSON.stringify(message);
  return `Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`;
}

function runLsp(messages) {
  const result = spawnSync(server, {
    cwd: packageRoot,
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
  const otherUri = "file:///tmp/tintin-completion-other.tt++";
  const responses = runLsp([
    initialize(),
    open(uri, "#al\n$h\n@h\n"),
    open(otherUri, "#variable {hp} {10}\n#function {heal} {#return ok}\n"),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "textDocument/completion",
      params: { textDocument: { uri }, position: { line: 0, character: 3 } },
    },
    {
      jsonrpc: "2.0",
      id: 3,
      method: "textDocument/completion",
      params: { textDocument: { uri }, position: { line: 1, character: 2 } },
    },
    {
      jsonrpc: "2.0",
      id: 4,
      method: "textDocument/completion",
      params: { textDocument: { uri }, position: { line: 2, character: 2 } },
    },
  ]);

  const completion = byId(responses, 2).result.find((item) => item.label === "#alias");
  assert(completion, "expected #alias completion");
  assert(completion.kind === 14, `expected #alias to be Keyword kind 14, got ${completion.kind}`);
  assert(completion.insertText === "#alias", `expected plain #alias insertText, got ${completion.insertText}`);
  assert(completion.insertTextFormat === 1, `expected plain-text insert format, got ${completion.insertTextFormat}`);
  assert(!completion.snippetText, "completion should not include snippetText");

  const variableCompletion = byId(responses, 3).result.find((item) => item.label === "$hp");
  assert(variableCompletion, "expected document-derived $hp completion");
  assert(variableCompletion.insertText === "$hp", "expected $hp completion insertText");

  const functionCompletion = byId(responses, 4).result.find((item) => item.label === "@heal");
  assert(functionCompletion, "expected document-derived @heal completion");
  assert(functionCompletion.insertText === "@heal", "expected @heal completion insertText");
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

function testSymbolsDefinitionsReferencesAndCrossDocumentRename() {
  const mainUri = "file:///tmp/tintin-main.tt++";
  const otherUri = "file:///tmp/tintin-other.tt++";
  const mainText = "#variable {hp} {10}\n#function {heal} {#return $hp}\n#send $hp\n";
  const otherText = "#alias {tick} {say $hp}\n#alias {cast} {#send @heal}\n";

  const responses = runLsp([
    initialize(),
    open(mainUri, mainText),
    open(otherUri, otherText),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "textDocument/documentSymbol",
      params: { textDocument: { uri: mainUri } },
    },
    {
      jsonrpc: "2.0",
      id: 3,
      method: "textDocument/definition",
      params: { textDocument: { uri: otherUri }, position: { line: 0, character: 20 } },
    },
    {
      jsonrpc: "2.0",
      id: 4,
      method: "textDocument/references",
      params: { textDocument: { uri: otherUri }, position: { line: 0, character: 20 }, context: { includeDeclaration: true } },
    },
    {
      jsonrpc: "2.0",
      id: 5,
      method: "textDocument/definition",
      params: { textDocument: { uri: otherUri }, position: { line: 1, character: 23 } },
    },
    {
      jsonrpc: "2.0",
      id: 6,
      method: "textDocument/rename",
      params: { textDocument: { uri: otherUri }, position: { line: 0, character: 20 }, newName: "health" },
    },
    {
      jsonrpc: "2.0",
      id: 7,
      method: "textDocument/references",
      params: { textDocument: { uri: otherUri }, position: { line: 0, character: 20 }, context: { includeDeclaration: false } },
    },
  ]);

  const symbols = byId(responses, 2).result;
  assert(symbols.some((symbol) => symbol.name === "hp" && symbol.kind === 13), "expected hp variable document symbol");
  assert(symbols.some((symbol) => symbol.name === "heal" && symbol.kind === 12), "expected heal function document symbol");

  const hpDefinitions = byId(responses, 3).result;
  assert(hpDefinitions.length === 1, `expected one hp definition, got ${hpDefinitions.length}`);
  assert(hpDefinitions[0].uri === mainUri, "hp definition should resolve to main document");

  const hpReferences = byId(responses, 4).result;
  assert(hpReferences.length === 4, `expected hp definition plus three references, got ${hpReferences.length}`);
  assert(hpReferences.some((reference) => reference.uri === otherUri), "expected cross-document hp reference");

  const healDefinitions = byId(responses, 5).result;
  assert(healDefinitions.length === 1, `expected one heal definition, got ${healDefinitions.length}`);
  assert(healDefinitions[0].uri === mainUri, "heal definition should resolve to main document");

  const renameChanges = byId(responses, 6).result.changes;
  assert(renameChanges[mainUri].length === 3, `expected three main-document hp rename edits, got ${renameChanges[mainUri].length}`);
  assert(renameChanges[otherUri].length === 1, `expected one raw-only other-document hp rename edit, got ${renameChanges[otherUri].length}`);

  const hpReferencesWithoutDefinition = byId(responses, 7).result;
  assert(
    hpReferencesWithoutDefinition.length === 3,
    `expected three hp references without definition, got ${hpReferencesWithoutDefinition.length}`
  );
  assert(
    hpReferencesWithoutDefinition.every((reference) => reference.range.start.line !== 0 || reference.uri !== mainUri),
    "references with includeDeclaration=false should exclude the definition"
  );
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

function testWorkspaceSymbolsFoldingRangesDocumentLinksAndCli() {
  const uri = "file:///tmp/tintin-project/main.tt++";
  const text = [
    "#variable {hp} {10}",
    "#alias {heal} {",
    "  say $hp",
    "}",
    "#read {scripts/common.tt}",
    "#textin \"scripts/quoted.tt\"",
    "#read {maps/@zone$1.tt}",
    "",
  ].join("\n");

  const responses = runLsp([
    initialize(),
    open(uri, text),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "workspace/symbol",
      params: { query: "hp" },
    },
    {
      jsonrpc: "2.0",
      id: 3,
      method: "textDocument/foldingRange",
      params: { textDocument: { uri } },
    },
    {
      jsonrpc: "2.0",
      id: 4,
      method: "textDocument/documentLink",
      params: { textDocument: { uri } },
    },
  ]);

  const workspaceSymbols = byId(responses, 2).result;
  assert(workspaceSymbols.some((symbol) => symbol.name === "hp" && symbol.location.uri === uri), "expected workspace symbol for hp");

  const folds = byId(responses, 3).result;
  assert(folds.some((fold) => fold.startLine === 1 && fold.endLine === 3), "expected multiline alias body folding range");

  const links = byId(responses, 4).result;
  assert(links.length === 3, `expected three document links, got ${links.length}`);
  assert(
    links.some((link) => link.target === "file:///tmp/tintin-project/scripts/common.tt"),
    "expected braced document link target"
  );
  assert(
    links.some((link) => link.target === "file:///tmp/tintin-project/scripts/quoted.tt"),
    "expected quoted document link target"
  );
  assert(
    links.some((link) => link.target === "file:///tmp/tintin-project/maps/@zone$1.tt"),
    "expected special-character document link target"
  );

  const version = spawnSync(server, ["--version"], { cwd: packageRoot, encoding: "utf8" });
  assert(version.status === 0, "--version should exit successfully");
  assert(version.stdout.trim() === packageJson.version, "--version should print package version");

  const help = spawnSync(server, ["--help"], { cwd: packageRoot, encoding: "utf8" });
  assert(help.status === 0, "--help should exit successfully");
  assert(help.stdout.includes("Usage:"), "--help should print usage");
}

function testCodeActionsForUnknownCommands() {
  const uri = "file:///tmp/tintin-actions.tt++";
  const text = "#varible {hp} {10}\n";
  const responses = runLsp([
    initialize(),
    open(uri, text),
    {
      jsonrpc: "2.0",
      id: 2,
      method: "textDocument/codeAction",
      params: {
        textDocument: { uri },
        range: {
          start: { line: 0, character: 0 },
          end: { line: 0, character: 8 },
        },
        context: {
          diagnostics: diagnostics(runLsp([initialize(), open(uri, text)])),
        },
      },
    },
    {
      jsonrpc: "2.0",
      id: 3,
      method: "textDocument/codeAction",
      params: {
        textDocument: { uri },
        range: {
          start: { line: 0, character: 8 },
          end: { line: 0, character: 13 },
        },
        context: {
          diagnostics: diagnostics(runLsp([initialize(), open(uri, text)])),
        },
      },
    },
    {
      jsonrpc: "2.0",
      id: 4,
      method: "textDocument/codeAction",
      params: {
        textDocument: { uri },
        range: {
          start: { line: 0, character: 0 },
          end: { line: 0, character: 8 },
        },
        context: {
          diagnostics: diagnostics(runLsp([initialize(), open(uri, text)])),
          only: ["source"],
        },
      },
    },
    {
      jsonrpc: "2.0",
      id: 5,
      method: "textDocument/codeAction",
      params: {
        textDocument: { uri },
        range: {
          start: { line: 0, character: 0 },
          end: { line: 0, character: 0 },
        },
        context: {
          diagnostics: diagnostics(runLsp([initialize(), open(uri, text)])),
        },
      },
    },
  ]);

  const actions = byId(responses, 2).result;
  const action = actions.find((item) => item.title === "Replace with #variable");
  assert(action, "expected #variable quick fix");
  assert(action.kind === "quickfix", "expected quickfix code action");
  assert(action.edit.changes[uri][0].newText === "#variable", "expected quickfix edit replacement");
  assert(byId(responses, 3).result.length === 0, "expected no quick fix for adjacent non-overlapping range");
  assert(byId(responses, 4).result.length === 0, "expected no quick fix when context.only excludes quickfix");
  assert(
    byId(responses, 5).result.some((item) => item.title === "Replace with #variable"),
    "expected quick fix for zero-length cursor range at diagnostic start"
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
    { jsonrpc: "2.0", id: 7, method: "workspace/symbol", params: { query: 42 } },
    { jsonrpc: "2.0", id: 8, method: "textDocument/foldingRange", params: {} },
    { jsonrpc: "2.0", id: 9, method: "textDocument/documentLink", params: {} },
    { jsonrpc: "2.0", id: 10, method: "textDocument/codeAction", params: { textDocument: { uri: "file:///tmp/a.tt++" } } },
  ]);

  for (const id of [2, 3, 4, 5, 6, 7, 8, 9, 10]) {
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

function testRequestMethodNotificationsDoNotRespond() {
  const uri = "file:///tmp/tintin-notification.tt++";
  const responses = runLsp([
    initialize(),
    open(uri, "#variable {hp} {10}\n#send $hp\n"),
    {
      jsonrpc: "2.0",
      method: "textDocument/completion",
      params: { textDocument: { uri }, position: { line: 0, character: 3 } },
    },
    {
      jsonrpc: "2.0",
      method: "textDocument/references",
      params: { textDocument: { uri }, position: { line: 1, character: 7 }, context: { includeDeclaration: true } },
    },
    {
      jsonrpc: "2.0",
      method: "textDocument/rename",
      params: { textDocument: { uri }, position: { line: 1, character: 7 }, newName: "health" },
    },
    {
      jsonrpc: "2.0",
      method: "workspace/symbol",
      params: { query: "hp" },
    },
    {
      jsonrpc: "2.0",
      method: "textDocument/foldingRange",
      params: { textDocument: { uri } },
    },
    {
      jsonrpc: "2.0",
      method: "textDocument/documentLink",
      params: { textDocument: { uri } },
    },
    {
      jsonrpc: "2.0",
      method: "textDocument/codeAction",
      params: {
        textDocument: { uri },
        range: { start: { line: 0, character: 0 }, end: { line: 0, character: 1 } },
        context: { diagnostics: [] },
      },
    },
  ]);

  assert(
    !responses.some((response) => response.method === undefined && response.id === undefined),
    "request-style notifications should not respond"
  );
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

function testServerInfoVersionMatchesPackage() {
  const responses = runLsp([initialize()]);
  const capabilities = byId(responses, 1).result.capabilities;
  assert(capabilities.workspaceSymbolProvider === true, "expected workspace symbol provider capability");
  assert(capabilities.foldingRangeProvider === true, "expected folding range provider capability");
  assert(capabilities.documentLinkProvider.resolveProvider === false, "expected document link provider capability");
  assert(capabilities.codeActionProvider.codeActionKinds.includes("quickfix"), "expected quickfix code action capability");
  assert(
    byId(responses, 1).result.serverInfo.version === packageJson.version,
    "serverInfo.version should match package.json version"
  );
}

const tests = [
  testCompletionItemsArePlainText,
  testParserDiagnosticsAndRename,
  testSymbolsDefinitionsReferencesAndCrossDocumentRename,
  testFormatterPreservesMultilineValues,
  testWorkspaceSymbolsFoldingRangesDocumentLinksAndCli,
  testCodeActionsForUnknownCommands,
  testInvalidParamsKeepRequestId,
  testRenameNameValidation,
  testKnownCommandsAndEmptyFormatting,
  testInitializeNotificationDoesNotRespond,
  testRequestMethodNotificationsDoNotRespond,
  testJsonRpcEnvelopeValidation,
  testServerInfoVersionMatchesPackage,
];

for (const test of tests) {
  test();
}

console.log(`ok: ${tests.length} tintin-lsp protocol tests passed`);
