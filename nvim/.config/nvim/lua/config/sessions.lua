local M = {}

function M.directory()
  local scope = "standalone"
  if vim.env.TMUX_PANE and vim.env.TMUX then
    local ok, result = pcall(function()
      return vim.system({
        "tmux", "display-message", "-p", "-t", vim.env.TMUX_PANE,
        "#{session_name}:#{window_index}.#{pane_index}",
      }, { text = true }):wait(1000)
    end)
    if not ok or result.code ~= 0 or not result.stdout or vim.trim(result.stdout) == "" then
      -- Avoid overwriting another pane's session when tmux is unavailable.
      return nil
    end
    scope = "tmux-" .. vim.fn.sha256(vim.trim(result.stdout))
  end
  return vim.fn.stdpath("state") .. "/sessions/" .. scope .. "/"
end

local function has_files()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buflisted and vim.bo[buffer].buftype == ""
      and vim.api.nvim_buf_get_name(buffer) ~= ""
      and not vim.tbl_contains({ "gitcommit", "gitrebase", "jj" }, vim.bo[buffer].filetype) then
      return true
    end
  end
  return false
end

function M.path()
  local directory = M.directory()
  return directory and (directory .. vim.fn.sha256(vim.fn.getcwd()) .. ".vim") or nil
end

function M.save()
  if not M.enabled or vim.g.SessionLoad or not has_files() then
    return false
  end
  -- Resolve coordinates for every snapshot: tmux can renumber or move panes.
  local path = M.path()
  if not path then
    return false
  end
  local temporary = path .. ".tmp." .. vim.fn.getpid()
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.cmd("mksession! " .. vim.fn.fnameescape(temporary))
    local renamed, rename_error = vim.uv.fs_rename(temporary, path)
    assert(renamed, rename_error)
  end)
  if not ok then
    vim.fn.delete(temporary)
    vim.notify("[sessions.save] " .. tostring(err), vim.log.levels.WARN)
  end
  return ok
end

function M.load()
  local path = M.path()
  if not path or vim.fn.filereadable(path) == 0 then
    return false
  end
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].modified then
      vim.notify("[sessions.load] Save modified buffers before restoring a session", vim.log.levels.WARN)
      return false
    end
  end
  local ok, err = pcall(vim.cmd, "silent source " .. vim.fn.fnameescape(path))
  if not ok then
    vim.notify("[sessions.load] " .. tostring(err), vim.log.levels.WARN)
  end
  return ok
end

function M.setup()
  -- Batch jobs, read-only views and Git's editor must not replace work sessions.
  if #vim.api.nvim_list_uis() == 0 or vim.o.readonly or vim.o.diff then
    return
  end
  if not M.directory() then
    vim.notify("[sessions.setup] tmux pane identity unavailable; session saving disabled", vim.log.levels.WARN)
    return
  end

  vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "folds" }
  M.enabled = true
  vim.keymap.set("n", "<leader>qs", M.save, { desc = "Save editor session" })
  vim.keymap.set("n", "<leader>qr", M.load, { desc = "Restore editor session" })
  local group = vim.api.nvim_create_augroup("dotfiles_sessions", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      if vim.fn.argc() == 0 and not vim.bo.modified then
        M.load()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWritePost", "FocusLost" }, {
    group = group,
    callback = function()
      M.save()
    end,
  })
  if M.timer then
    M.timer:stop()
    M.timer:close()
  end
  M.timer = vim.uv.new_timer()
  M.timer:start(60000, 60000, vim.schedule_wrap(M.save))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.save()
      M.timer:stop()
      M.timer:close()
    end,
  })
end

return M
