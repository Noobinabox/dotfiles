local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local repo_root = vim.fn.fnamemodify(config_root, ":h:h:h")
vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
local options
for _, spec in ipairs(dofile(config_root .. "/lua/plugins/editor.lua")) do
  if spec[1] == "folke/snacks.nvim" then
    options = spec.opts
  end
end
require("snacks").setup(options)

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/tools/.config/mud-client/scripts", "p")
local ok, err = pcall(function()
  assert(vim.system({ "git", "init", "-q", root }):wait().code == 0)
  vim.fn.writefile({ "ignored.txt" }, root .. "/.gitignore")
  vim.fn.writefile({ "fixture" }, root .. "/ignored.txt")
  vim.fn.writefile({ "fixture" }, root .. "/.git/private-fixture")
  vim.fn.writefile({ "fixture" }, root .. "/visible.txt")
  vim.fn.writefile({ "-- fixture" }, root .. "/tools/.config/mud-client/scripts/skjor.lua")

  local command
  package.loaded["snacks.picker.source.proc"] = {
    proc = function(opts)
      command = { opts.cmd }
      vim.list_extend(command, opts.args)
      return function() end
    end,
  }
  local function find(cwd, backend)
    local opts = Snacks.picker.config.get({ source = "files", cwd = cwd, cmd = backend })
    assert(opts.hidden == true and opts.ignored == false)
    require("snacks.picker.source.files").files(opts, {
      filter = { search = "" },
      opts = function(_, overrides) return vim.tbl_extend("force", opts, overrides) end,
    })
    local result = vim.system(command, { cwd = cwd, text = true }):wait()
    assert(result.code == 0, result.stderr)
    return result.stdout
  end
  local tested = 0
  for _, backend in ipairs({ "fd", "fdfind", "rg" }) do
    if vim.fn.executable(backend) == 1 then
      local files = find(root, backend)
      assert(files:find("tools/.config/mud-client/scripts/skjor.lua", 1, true), "Hidden config missing")
      assert(files:find("visible.txt", 1, true), "Visible file missing")
      assert(not files:find("ignored.txt", 1, true), "Git-ignored file exposed")
      assert(not files:find("private-fixture", 1, true), "Git metadata exposed")
      assert(find(repo_root, backend):find("tools/.config/mud-client/scripts/skjor.lua", 1, true),
        "Actual MUD script missing from dotfiles results")
      tested = tested + 1
    end
  end
  assert(tested > 0, "Install fd, fdfind, or rg to run this regression")
end)
vim.fn.delete(root, "rf")
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd.cquit()
end
print("File picker hidden-file and ignore checks passed")
vim.cmd.qa()
