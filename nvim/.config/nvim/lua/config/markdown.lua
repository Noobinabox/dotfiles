local M = {}

local markdown_filetypes = {
  markdown = true,
  mdx = true,
  ["markdown.mdx"] = true,
}

local dictionary_preview = {
  bufnr = nil,
  winid = nil,
}

local link_keymap_desc = "Open Markdown link or fallback"
local url_pattern = "[%w][%w+.-]*://[^%s%]%)>}\"']+"
local www_pattern = "www%.[^%s%]%)>}\"']+"

local function now()
  return os.date("%Y-%m-%d %H:%M:%S")
end

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_markdown_buffer(buf)
  return markdown_filetypes[vim.bo[buf].filetype] == true
end

local function cursor_col()
  return vim.api.nvim_win_get_cursor(0)[2] + 1
end

local function cursor_is_inside(start_col, end_col)
  local col = cursor_col()
  return start_col <= col and col < end_col
end

local function normalize_url(url)
  url = trim(url or "")

  if url:match("^https?://") then
    return url
  end

  if url:match("^www%.") then
    return "https://" .. url
  end
end

local function markdown_link_destination(raw_destination)
  local destination = trim(raw_destination or "")
  local angle_destination = destination:match("^<([^>]+)>")

  if angle_destination then
    return angle_destination
  end

  return destination:match("^(%S+)")
end

local function find_markdown_link_end(line, start_col)
  local depth = 1
  local col = start_col

  while col <= #line do
    local char = line:sub(col, col)
    local previous = line:sub(col - 1, col - 1)

    if char == "(" and previous ~= "\\" then
      depth = depth + 1
    elseif char == ")" and previous ~= "\\" then
      depth = depth - 1

      if depth == 0 then
        return col
      end
    end

    col = col + 1
  end
end

local function find_markdown_link(line)
  local search_col = 1

  while search_col <= #line do
    local label_start, label_end = line:find("%[[^%]]-%]%(", search_col)

    if not label_start then
      return
    end

    local destination_start = label_end + 1
    local link_end = find_markdown_link_end(line, destination_start)

    if link_end and cursor_is_inside(label_start, link_end + 1) then
      local destination = line:sub(destination_start, link_end - 1)
      return normalize_url(markdown_link_destination(destination))
    end

    search_col = label_end + 1
  end
end

local function find_raw_url(line)
  for start_col, url, end_col in line:gmatch("()(" .. url_pattern .. ")()") do
    if cursor_is_inside(start_col, end_col) then
      return normalize_url(url)
    end
  end

  for start_col, url, end_col in line:gmatch("()(" .. www_pattern .. ")()") do
    if cursor_is_inside(start_col, end_col) then
      return normalize_url(url)
    end
  end
end

local function output_lines(result)
  local output = result.stdout or ""
  if output == "" then
    output = result.stderr or ""
  end

  output = output:gsub("\r\n", "\n"):gsub("%s+$", "")

  if output == "" then
    return {}
  end

  return vim.split(output, "\n", { plain = true, trimempty = false })
end

local function dictionary_preview_is_open()
  return dictionary_preview.winid ~= nil and vim.api.nvim_win_is_valid(dictionary_preview.winid)
end

local function close_dictionary_preview()
  if dictionary_preview_is_open() then
    pcall(vim.api.nvim_win_close, dictionary_preview.winid, true)
  end

  dictionary_preview.bufnr = nil
  dictionary_preview.winid = nil
end

local function focus_dictionary_preview()
  if not dictionary_preview_is_open() then
    return false
  end

  vim.api.nvim_set_current_win(dictionary_preview.winid)
  return true
end

local function set_preview_keymaps(buf)
  vim.keymap.set("n", "q", close_dictionary_preview, {
    buffer = buf,
    desc = "Close dictionary preview",
    nowait = true,
    silent = true,
  })
end

local function show_definition(lines)
  local max_width = math.max(1, vim.o.columns - 8)
  local max_height = math.max(1, vim.o.lines - 6)

  local bufnr, winid = vim.lsp.util.open_floating_preview(lines, "text", {
    border = "rounded",
    focusable = true,
    max_height = math.min(#lines, max_height),
    max_width = math.min(100, max_width),
  })

  dictionary_preview.bufnr = bufnr
  dictionary_preview.winid = winid

  set_preview_keymaps(bufnr)
end

function M.lookup_word_definition(word)
  if word == nil and focus_dictionary_preview() then
    return
  end

  word = trim(word or vim.fn.expand("<cword>"))

  if word == "" then
    vim.notify("No word under cursor", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("dict") == 0 then
    vim.notify("dict executable not found", vim.log.levels.WARN)
    return
  end

  vim.system({ "dict", word }, { text = true }, function(result)
    vim.schedule(function()
      local lines = output_lines(result)

      if #lines == 0 then
        vim.notify(("No definition found for %q"):format(word), vim.log.levels.INFO)
        return
      end

      show_definition(lines)
    end)
  end)
end

local function set_dictionary_keymap(buf)
  vim.keymap.set("n", "K", M.lookup_word_definition, {
    buffer = buf,
    desc = "Dictionary definition",
    silent = true,
  })
end

function M.open_link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local url = find_markdown_link(line) or find_raw_url(line)

  if not url then
    return false
  end

  local _, err = vim.ui.open(url)

  if err then
    vim.notify(("Unable to open %s: %s"):format(url, err), vim.log.levels.ERROR)
  end

  return true
end

function M.set_link_keymap(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  local current_enter = vim.api.nvim_buf_call(buf, function()
    return vim.fn.maparg("<CR>", "n", false, true)
  end)

  if current_enter.desc ~= link_keymap_desc then
    vim.b[buf].markdown_link_open_previous_enter = current_enter
  end

  local function fallback_enter()
    local previous_enter = vim.b[buf].markdown_link_open_previous_enter

    if vim.tbl_isempty(previous_enter) then
      local enter = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
      vim.api.nvim_feedkeys(enter, "n", false)
      return
    end

    if previous_enter.callback then
      local callback_rhs = previous_enter.callback()

      if type(callback_rhs) == "string" and callback_rhs ~= "" then
        local keys = vim.api.nvim_replace_termcodes(callback_rhs, true, false, true)
        vim.api.nvim_feedkeys(keys, previous_enter.noremap == 1 and "n" or "m", false)
      end

      return
    end

    local rhs = previous_enter.rhs
    if type(rhs) ~= "string" or rhs == "" then
      return
    end

    if previous_enter.expr == 1 then
      local ok, expr_rhs = pcall(vim.api.nvim_eval, rhs)

      if not ok or type(expr_rhs) ~= "string" then
        return
      end

      rhs = expr_rhs
    end

    local keys = vim.api.nvim_replace_termcodes(rhs, true, false, true)
    local mode = previous_enter.noremap == 1 and "n" or "m"
    vim.api.nvim_feedkeys(keys, mode, false)
  end

  vim.keymap.set("n", "<CR>", function()
    if M.open_link_under_cursor() then
      return
    end

    fallback_enter()
  end, {
    buffer = buf,
    desc = link_keymap_desc,
    silent = true,
  })
end

local function is_frontmatter_delimiter(line)
  return type(line) == "string" and line:match("^%-%-%-%s*$") ~= nil
end

local function frontmatter_lines(buf)
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count < 2 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, line_count, false)
  if not is_frontmatter_delimiter(lines[1]) then
    return nil
  end

  for i = 2, #lines do
    if is_frontmatter_delimiter(lines[i]) then
      return vim.list_slice(lines, 1, i), i
    end
  end
end

local function find_property(lines, name)
  local pattern = "^%s*" .. name .. "%s*:"

  for i = 2, #lines - 1 do
    if lines[i]:match(pattern) then
      return i
    end
  end
end

local function property_is_blank(line, name)
  local value = line:gsub("^%s*" .. name .. "%s*:%s*", "")
  return value:match("^%s*$") ~= nil
end

function M.update_frontmatter_timestamps(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_get_option_value("modifiable", { buf = buf }) then
    return
  end

  local lines, end_line = frontmatter_lines(buf)
  if not lines then
    return
  end

  local timestamp = now()
  local file = vim.api.nvim_buf_get_name(buf)
  local file_is_new = file == "" or vim.uv.fs_stat(file) == nil
  local changed = false

  local created_idx = find_property(lines, "created")
  if created_idx then
    local should_set_created = file_is_new or property_is_blank(lines[created_idx], "created")
    if should_set_created and lines[created_idx] ~= "created: " .. timestamp then
      lines[created_idx] = "created: " .. timestamp
      changed = true
    end
  else
    table.insert(lines, 2, "created: " .. timestamp)
    created_idx = 2
    changed = true
  end

  local updated_idx = find_property(lines, "updated")
  if updated_idx then
    if lines[updated_idx] ~= "updated: " .. timestamp then
      lines[updated_idx] = "updated: " .. timestamp
      changed = true
    end
  else
    table.insert(lines, created_idx + 1, "updated: " .. timestamp)
    changed = true
  end

  if changed then
    vim.api.nvim_buf_set_lines(buf, 0, end_line, false, lines)
  end
end

local group = vim.api.nvim_create_augroup("MarkdownFrontmatterTimestamps", { clear = true })
local dictionary_group = vim.api.nvim_create_augroup("MarkdownDictionaryLookup", { clear = true })
local link_group = vim.api.nvim_create_augroup("MarkdownLinkOpen", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  pattern = { "*.md", "*.markdown", "*.mdx" },
  callback = function(args)
    M.update_frontmatter_timestamps(args.buf)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = dictionary_group,
  pattern = vim.tbl_keys(markdown_filetypes),
  callback = function(args)
    set_dictionary_keymap(args.buf)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = link_group,
  pattern = vim.tbl_keys(markdown_filetypes),
  callback = function(args)
    M.set_link_keymap(args.buf)
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = dictionary_group,
  callback = function(args)
    if not is_markdown_buffer(args.buf) then
      return
    end

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) and is_markdown_buffer(args.buf) then
        set_dictionary_keymap(args.buf)
      end
    end)
  end,
})

return M
