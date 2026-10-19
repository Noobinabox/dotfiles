local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(config_root)

local captured = {}
local original_config = vim.lsp.config
local original_enable = vim.lsp.enable
vim.lsp.config = function(name, config)
  captured[name] = config
end
vim.lsp.enable = function() end
package.preload["blink.cmp"] = function()
  return { get_lsp_capabilities = function() return {} end }
end
package.preload["mason-lspconfig"] = function()
  return { setup = function() end }
end
for _, spec in ipairs(dofile(config_root .. "/lua/plugins/lsp.lua")) do
  if spec[1] == "mason-org/mason-lspconfig.nvim" then
    spec.config(nil, spec.opts)
  end
end
vim.lsp.config = original_config
vim.lsp.enable = original_enable

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local client
local ok, err = pcall(function()
  local api = vim.fn.expand("~/.config/mud-client/scripts/mud-client-api.lua")
  assert(vim.tbl_contains(captured.lua_ls.settings.Lua.workspace.library, api))
  assert(vim.fn.filereadable(api) == 1, "MUD API annotations are missing")
  local file = root .. "/standalone.lua"
  vim.fn.writefile({ 'client.send("look")' }, file)
  vim.cmd.edit(vim.fn.fnameescape(file))
  local id = vim.lsp.start({
    name = "mud-lua-test",
    cmd = { vim.fn.stdpath("data") .. "/mason/bin/lua-language-server" },
    root_dir = root,
    settings = captured.lua_ls.settings,
  })
  assert(id, "LuaLS failed to start")
  client = vim.lsp.get_client_by_id(id)
  assert(vim.wait(10000, function() return client.initialized end, 50), "LuaLS initialization timed out")
  local hover
  for _ = 1, 40 do
    local response = client:request_sync("textDocument/hover", {
      textDocument = { uri = vim.uri_from_fname(file) },
      position = { line = 0, character = 2 },
    }, 1000, 0)
    hover = response and response.result
    if hover and vim.inspect(hover):find("MudClientApi", 1, true) then
      break
    end
    vim.wait(200)
  end
  assert(hover and vim.inspect(hover):find("MudClientApi", 1, true),
    "Standalone Lua did not receive the MudClientApi hover type: " .. vim.inspect(hover))
end)
if client then
  client:stop(true)
end
vim.fn.delete(root, "rf")
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd.cquit()
end
print("MUD LuaLS standalone annotation check passed")
vim.cmd.qa()
