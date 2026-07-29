local keymap = vim.keymap
local wk = require("which-key")

keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open netrw" })

keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

keymap.set("n", "Y", "yg$", { desc = "Yank to end of line" })
keymap.set("n", "J", "mzJ`z", { desc = "Join lines" })
keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Move down by visual line" })
keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Move up by visual line" })
keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down" })
keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up" })
keymap.set("n", "n", "nzzzv", { desc = "Next search result" })
keymap.set("n", "N", "Nzzzv", { desc = "Previous search result" })

keymap.set("n", "<leader>nh", ":noh<CR>", { desc = "Clear search highlights" })
keymap.set("n", "<leader>nd", function()
  if vim.fn.exists(":NoiceDismiss") == 2 then
    vim.cmd("NoiceDismiss")
  else
    vim.notify("Noice is not installed", vim.log.levels.WARN)
  end
end, { desc = "Dismiss Noice" })

local function current_working_dir()
  return vim.uv.cwd() or vim.fn.getcwd()
end

local function current_root_dir()
  return Snacks.git.get_root() or current_working_dir()
end

keymap.set("n", "<leader><leader>", function()
  Snacks.picker.files({ cwd = current_root_dir() })
end, { desc = "Find files" })
keymap.set("n", "<leader>/", function()
  Snacks.picker.grep({ cwd = current_root_dir() })
end, { desc = "Live grep" })
keymap.set("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, { desc = "Buffers" })
keymap.set("n", "<leader>fB", function()
  Snacks.picker.buffers({ hidden = true, nofile = true })
end, { desc = "Buffers (all)" })
keymap.set("n", "<leader>fc", function()
  Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find config file" })
keymap.set("n", "<leader>ff", function()
  Snacks.picker.files({ cwd = current_root_dir() })
end, { desc = "Find files (root dir)" })
keymap.set("n", "<leader>fF", function()
  Snacks.picker.files({ cwd = current_working_dir() })
end, { desc = "Find files (cwd)" })
keymap.set("n", "<leader>fg", function()
  Snacks.picker.git_files()
end, { desc = "Find files (git files)" })
keymap.set("n", "<leader>fr", function()
  Snacks.picker.recent()
end, { desc = "Recent" })
keymap.set("n", "<leader>fR", function()
  Snacks.picker.recent({ filter = { cwd = true } })
end, { desc = "Recent (cwd)" })
keymap.set("n", "<leader>fp", function()
  Snacks.picker.projects()
end, { desc = "Projects" })
keymap.set("n", "<leader>ph", function()
  Snacks.picker.help()
end, { desc = "Help tags" })

keymap.set("n", "<C-s>", vim.cmd.write, { desc = "Save buffer" })
keymap.set("i", "<C-s>", "<Esc><cmd>write<CR>a", { desc = "Save buffer" })
keymap.set({ "v", "x" }, "<C-s>", "<Esc><cmd>write<CR>", { desc = "Save buffer" })

keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })
keymap.set("n", "<leader>w", "<C-w>", { desc = "Window commands" })

keymap.set("x", "<leader>p", '"_dP', { desc = "Paste without yanking" })

keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
keymap.set("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })

keymap.set({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete without yanking" })

keymap.set("i", "<C-c>", "<Esc>", { desc = "Exit insert mode" })

keymap.set("n", "Q", "<nop>")
keymap.set("n", "q:", ":q<CR>", { desc = "Quit" })

wk.add({
  { "<leader>n", group = "Notes" },
  { "<leader>nr", group = "Obsidian" },
  { "<leader>nrd", group = "Date" },
  { "<leader>a", group = "AI" },
  { "<leader>ac", group = "Copilot" },
  { "<leader>f", group = "File/Find" },
  { "<leader>p", group = "Pick" },
  { "<leader>w", proxy = "<C-w>", group = "Window" },
  { "<leader>c", group = "Code", mode = { "n", "v" } },
  { "<leader>x", group = "Diagnostics/Quickfix" },
  { "gs", group = "Surround", mode = { "n", "x" } },
})

keymap.set("n", "<leader>nrdt", function()
  vim.cmd("Obsidian today")
end, { desc = "Obsidian note today" })
keymap.set("n", "<leader>nrdy", function()
  vim.cmd("Obsidian yesterday")
end, { desc = "Obsidian note yesterday" })
keymap.set("n", "<leader>nrf", function()
  vim.cmd("Obsidian quick_switch")
end, { desc = "Obsidian quick switch" })
keymap.set("n", "<leader>nrr", function()
  vim.cmd("Obsidian backlinks")
end, { desc = "Obsidian backlinks" })
keymap.set("n", "<leader>nrl", function()
  vim.cmd("Obsidian links")
end, { desc = "Obsidian links" })
keymap.set("n", "<leader>nrp", function()
  require("obsidian.actions").start_presentation(vim.api.nvim_get_current_buf())
end, { desc = "Obsidian start presentation" })
keymap.set("n", "<leader>nrt", function()
  vim.cmd("Obsidian tags")
end, { desc = "Obsidian tags" })
keymap.set("n", "<leader>nn", function()
  vim.cmd("Obsidian new")
end, { desc = "Obsidian new note" })
keymap.set("v", "<leader>nn", ":Obsidian extract_note<CR>", { desc = "Obsidian extract note" })
keymap.set("n", "<leader>no", function()
  vim.cmd("Obsidian")
end, { desc = "Obsidian options" })

local buffer_key = "<leader>b"
keymap.set("n", "H", vim.cmd.bp, { desc = "Previous buffer" })
keymap.set("n", "L", vim.cmd.bn, { desc = "Next buffer" })
keymap.set("n", buffer_key .. "d", vim.cmd.bdelete, { desc = "Delete buffer" })
keymap.set("n", buffer_key .. "s", vim.cmd.write, { desc = "Save buffer" })
keymap.set("n", buffer_key .. "k", vim.cmd.bdelete, { desc = "Delete buffer" })
keymap.set("n", buffer_key .. "K", ":bufdo bd<CR>", { desc = "Delete all buffers" })
keymap.set("n", buffer_key .. "o", function()
  local current = vim.api.nvim_get_current_buf()

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.bo[buf].buflisted then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end, { desc = "Delete other buffers" })
keymap.set("n", buffer_key .. "p", vim.cmd.bp, { desc = "Previous buffer" })
keymap.set("n", buffer_key .. "n", vim.cmd.bn, { desc = "Next buffer" })

wk.add({
  {
    "<leader>b",
    group = "buffer",
    expand = function()
      return require("which-key.extras").expand.buf()
    end,
  },
})

vim.api.nvim_create_user_command("Q", "q", {})
vim.api.nvim_create_user_command("W", "w", {})

local function insert_current_date()
  local date = os.date("%Y-%m-%d %a")
  vim.api.nvim_put({ date }, "c", true, true)
end

keymap.set(
  "n",
  "<leader>mdt",
  insert_current_date,
  { noremap = true, silent = true, desc = "Insert current date (YYYY-mm-dd)" }
)

keymap.set(
  "v",
  "<leader>mt",
  [[:s/\<\w\+\>/\u\0/g<CR>]],
  { desc = "Capitalize each word in visual selection" }
)

wk.add({
  { "<leader>m", group = "markdown", mode = { "n", "v" } },
  { "<leader>md", group = "date", mode = "n" },
})
