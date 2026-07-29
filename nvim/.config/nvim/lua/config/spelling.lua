local M = {}

M.spellfile = vim.fn.stdpath("config") .. "/en.utf-8.add"
M.codebook_config = vim.fn.stdpath("config") .. "/codebook.toml"

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function toml_escape(value)
  return value:gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function read_spell_words()
  local ok, lines = pcall(vim.fn.readfile, M.spellfile)
  if not ok then
    return {}
  end

  local seen = {}
  local words = {}

  for _, line in ipairs(lines) do
    local word = trim(line)

    if word ~= "" and not word:match("^[#!/]") then
      local base, flags = word:match("^(.-)/(.+)$")
      if flags and flags:find("!", 1, true) then
        word = ""
      elseif base then
        word = base
      end

      if word ~= "" and not seen[word] then
        seen[word] = true
        table.insert(words, word)
      end
    end
  end

  table.sort(words)
  return words
end

local function codebook_lines()
  local lines = {
    "# Generated from en.utf-8.add.",
    "# Edit the Neovim spellfile, then run :SpellingSyncCodebook.",
    'dictionaries = ["en_us"]',
    "",
    "words = [",
  }

  for _, word in ipairs(read_spell_words()) do
    table.insert(lines, ('  "%s",'):format(toml_escape(word)))
  end

  table.insert(lines, "]")

  return lines
end

function M.sync_codebook_config()
  local lines = codebook_lines()
  local current = {}

  if vim.uv.fs_stat(M.codebook_config) then
    current = vim.fn.readfile(M.codebook_config)
  end

  if table.concat(current, "\n") == table.concat(lines, "\n") then
    return
  end

  vim.fn.writefile(lines, M.codebook_config)
end

function M.setup()
  M.sync_codebook_config()

  local group = vim.api.nvim_create_augroup("UserSpellingConfig", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = M.spellfile,
    callback = M.sync_codebook_config,
  })

  vim.api.nvim_create_user_command("SpellingSyncCodebook", M.sync_codebook_config, {
    desc = "Sync Codebook words from Neovim spellfile",
  })
end

return M
