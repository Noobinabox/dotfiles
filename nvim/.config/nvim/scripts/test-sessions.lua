local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(config_root)
local sessions = require("config.sessions")

-- Headless jobs must never save over an interactive editor's workspace.
sessions.setup()
assert(not sessions.enabled, "headless jobs must not enable persistence")

vim.env.TMUX = nil
vim.env.TMUX_PANE = nil
local standalone = sessions.directory()
assert(standalone:find("/sessions/standalone/", 1, true))

-- Stable pane coordinates survive changed runtime pane IDs after a restart.
local original_system = vim.system
local identity = "project:1.1\n"
vim.env.TMUX = "test-server"
vim.env.TMUX_PANE = "%1"
vim.system = function()
  return { wait = function() return { code = 0, stdout = identity } end }
end
local first_pane = sessions.directory()
vim.env.TMUX_PANE = "%99"
assert(first_pane == sessions.directory(), "runtime pane IDs must not change the session namespace")
identity = "project:1.2\n"
assert(first_pane ~= sessions.directory(), "editors in separate panes need distinct namespaces")
vim.system = function() error("tmux unavailable") end
assert(sessions.directory() == nil, "tmux failures must not share a fallback session")
vim.system = original_system
vim.env.TMUX = nil
vim.env.TMUX_PANE = nil

-- Round-trip native sessions containing file buffers, splits, tabs and cursors.
local original_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function() return { {} } end
sessions.setup()
vim.api.nvim_list_uis = original_uis
assert(sessions.enabled)
local root = vim.fn.stdpath("state") .. "/session-fixtures"
vim.fn.mkdir(root, "p")
local first = root .. "/first file.txt"
local second = root .. "/second.txt"
vim.fn.writefile({ "one", "two", "three", "four" }, first)
vim.fn.writefile({ "other" }, second)
vim.cmd.cd(vim.fn.fnameescape(root))
vim.cmd.edit(vim.fn.fnameescape(first))
vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.cmd.vsplit(vim.fn.fnameescape(second))
vim.cmd.tabnew(vim.fn.fnameescape(first))
vim.api.nvim_win_set_cursor(0, { 3, 0 })
assert(sessions.save())
local snapshot = sessions.path()
assert(vim.fn.filereadable(snapshot) == 1, "session snapshot must be written")
assert(snapshot:find(standalone, 1, true) == 1, "snapshots must stay in the state directory")
vim.cmd("tabonly | only | enew")
assert(sessions.load())
assert(#vim.api.nvim_list_tabpages() == 2, "tabs must restore")
assert(#vim.api.nvim_list_wins() == 3, "splits must restore")
assert(vim.api.nvim_buf_get_name(0) == first, "active file must restore")
assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "cursor position must restore")

-- Successful autosaves must not unregister their event callbacks.
for _, event in ipairs({ "BufWritePost", "FocusLost" }) do
  vim.api.nvim_exec_autocmds(event, {})
  vim.api.nvim_exec_autocmds(event, {})
  assert(#vim.api.nvim_get_autocmds({ group = "dotfiles_sessions", event = event }) == 1,
    "autosave callback must survive repeated " .. event .. " events")
end

-- Session saving records layout, never writes unsaved file contents.
vim.api.nvim_buf_set_lines(0, 0, 1, false, { "unsaved edit" })
assert(sessions.save())
assert(vim.fn.readfile(first)[1] == "one", "session saving must not write edited text")
local original_notify = vim.notify
vim.notify = function() end
assert(not sessions.load(), "restoration must protect unsaved edits")
vim.bo.modified = false

-- A failed atomic replacement preserves the previous valid snapshot.
local saved = vim.fn.readfile(snapshot)
local original_rename = vim.uv.fs_rename
vim.uv.fs_rename = function() return nil, "simulated disk failure" end
assert(not sessions.save(), "failed snapshot replacement must be reported")
vim.uv.fs_rename = original_rename
assert(vim.deep_equal(saved, vim.fn.readfile(snapshot)), "failed saves must retain the old session")
vim.notify = original_notify

-- Snapshots follow changed coordinates while the editor remains open.
vim.env.TMUX = "test-server"
vim.env.TMUX_PANE = "%99"
identity = "project:2.1\n"
vim.system = function()
  return { wait = function() return { code = 0, stdout = identity } end }
end
assert(sessions.save())
local old_path = sessions.path()
identity = "project:1.1\n"
assert(sessions.save())
assert(sessions.path() ~= old_path, "window renumbering must change snapshot identity")
assert(vim.fn.filereadable(sessions.path()) == 1, "new coordinates must receive a snapshot")
vim.system = original_system
vim.env.TMUX = nil
vim.env.TMUX_PANE = nil

-- VimEnter restores a plain startup, but explicit filenames remain selected.
local original_argc = vim.fn.argc
local argc = 1
vim.fn.argc = function() return argc end
vim.api.nvim_list_uis = function() return { {} } end
sessions.setup()
vim.cmd("tabonly | only | enew")
vim.cmd.edit(vim.fn.fnameescape(second))
vim.api.nvim_exec_autocmds("VimEnter", {})
assert(#vim.api.nvim_list_tabpages() == 1, "explicit filenames must suppress auto-restore")
assert(vim.api.nvim_buf_get_name(0) == second)
argc = 0
sessions.setup()
vim.cmd.enew()
vim.api.nvim_exec_autocmds("VimEnter", {})
assert(#vim.api.nvim_list_tabpages() == 2, "plain startup must automatically restore tabs")
assert(vim.api.nvim_buf_get_name(0) == first)
vim.fn.argc = original_argc
vim.api.nvim_list_uis = original_uis

-- Special-only buffers must not replace a saved editing workspace.
saved = vim.fn.readfile(snapshot)
vim.cmd("tabonly | only")
for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
  vim.api.nvim_buf_delete(buffer, { force = true })
end
vim.cmd.enew()
vim.api.nvim_buf_set_name(0, root .. "/COMMIT_EDITMSG")
vim.bo.filetype = "gitcommit"
assert(not sessions.save(), "Git editor buffers must not become work sessions")
assert(vim.deep_equal(saved, vim.fn.readfile(snapshot)))
sessions.enabled = false
print("Neovim session recovery checks passed")
