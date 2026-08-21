local M = {}

local state_by_buf = {}
local raw_fallback_by_buf = {}
local identity_namespace = vim.api.nvim_create_namespace("user-notebook-identity")
local display_namespace = vim.api.nvim_create_namespace("user-notebook-display")

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Notebook" })
end

local function read_file(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil, "missing"
  end

  if stat.type ~= "file" then
    error(("Unable to read %s: path is a %s, not a file"):format(path, stat.type))
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    error(("Unable to read %s: %s"):format(path, lines))
  end

  return table.concat(lines, "\n")
end

local function write_lines(path, lines)
  local ok, result = pcall(vim.fn.writefile, lines, path)
  if not ok then
    error(("Unable to write %s: %s"):format(path, result))
  end

  if result ~= 0 then
    error(("Unable to write %s: writefile returned %s"):format(path, result))
  end
end

local function write_file(path, content)
  write_lines(path, vim.split(content, "\n", { plain = true }))
end

local function set_notebook_window_options(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
    end
  end
end

local function source_to_lines(source)
  if type(source) == "table" then
    local lines = {}

    for _, part in ipairs(source) do
      local split = vim.split(tostring(part), "\n", { plain = true })
      for index, line in ipairs(split) do
        if index < #split or line ~= "" then
          table.insert(lines, line)
        end
      end
    end

    return lines
  end

  if type(source) == "string" then
    return vim.split(source, "\n", { plain = true })
  end

  return {}
end

local function cell_source_style(cell)
  if type(cell.source) == "table" then
    return "array"
  end

  return "string"
end

local function lines_to_source(lines, style)
  if style ~= "array" then
    return table.concat(lines, "\n")
  end

  local source = {}
  for index, line in ipairs(lines) do
    if index < #lines then
      table.insert(source, line .. "\n")
    else
      table.insert(source, line)
    end
  end

  return source
end

local function render_markdown_line(line)
  if line == "" then
    return "#"
  end

  return "# " .. line
end

local function parse_markdown_line(line)
  if line == "#" then
    return ""
  end

  if vim.startswith(line, "# ") then
    return line:sub(3)
  end

  if vim.startswith(line, "#") then
    return line:sub(2)
  end

  return line
end

local function render_raw_line(line)
  if line == "" then
    return "# |"
  end

  return "# | " .. line
end

local function parse_raw_line(line)
  if line == "# |" then
    return ""
  end

  if vim.startswith(line, "# | ") then
    return line:sub(5)
  end

  if vim.startswith(line, "# |") then
    return line:sub(4)
  end

  return line
end

local function marker_for_cell(cell)
  if cell.cell_type == "markdown" then
    return "# %% [markdown]"
  end

  if cell.cell_type == "raw" then
    return "# %% [raw]"
  end

  return "# %%"
end

local function render_notebook(notebook)
  local lines = {}
  local cells = notebook.cells or {}

  for cell_index, cell in ipairs(cells) do
    if cell_index > 1 then
      table.insert(lines, "")
    end

    table.insert(lines, marker_for_cell(cell))

    for _, line in ipairs(source_to_lines(cell.source)) do
      if cell.cell_type == "markdown" then
        table.insert(lines, render_markdown_line(line))
      elseif cell.cell_type == "raw" then
        table.insert(lines, render_raw_line(line))
      else
        table.insert(lines, line)
      end
    end
  end

  if #cells == 0 then
    table.insert(lines, "# %%")
  end

  return lines
end

local function parse_marker(line)
  local marker = line:match("^# %%%%%s*(.-)%s*$")
  if not marker then
    return nil
  end

  if marker == "" then
    return "code"
  end

  if marker == "[markdown]" then
    return "markdown"
  end

  if marker == "[raw]" then
    return "raw"
  end

  return nil
end

local function parse_cells(lines, marker_id_for_line)
  local cells = {}
  local current = nil

  local function remove_separator_blank()
    if current and current.lines[#current.lines] == "" then
      table.remove(current.lines)
    end
  end

  local function start_cell(cell_type, marker_id)
    if current then
      remove_separator_blank()
      table.insert(cells, current)
    end

    current = {
      cell_type = cell_type,
      marker_id = marker_id,
      lines = {},
    }
  end

  for line_number, line in ipairs(lines) do
    local cell_type = parse_marker(line)
    if cell_type then
      local marker_id = marker_id_for_line and marker_id_for_line(line_number - 1) or nil
      start_cell(cell_type, marker_id)
    else
      if not current then
        start_cell("code")
      end

      if current.cell_type == "markdown" then
        table.insert(current.lines, parse_markdown_line(line))
      elseif current.cell_type == "raw" then
        table.insert(current.lines, parse_raw_line(line))
      else
        table.insert(current.lines, line)
      end
    end
  end

  if current then
    table.insert(cells, current)
  end

  if #cells == 0 then
    table.insert(cells, { cell_type = "code", lines = {} })
  end

  return cells
end

local function marker_extmark_id(buf, line_number)
  local marks = vim.api.nvim_buf_get_extmarks(buf, identity_namespace, { line_number, 0 }, { line_number, -1 }, {})
  if #marks == 0 then
    return nil
  end

  return marks[1][1]
end

local function set_cell_extmarks(buf, cell_count)
  vim.api.nvim_buf_clear_namespace(buf, identity_namespace, 0, -1)

  local cell_index = 1
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for line_index, line in ipairs(lines) do
    if cell_index > cell_count then
      return
    end

    if parse_marker(line) then
      vim.api.nvim_buf_set_extmark(buf, identity_namespace, line_index - 1, 0, {
        id = cell_index,
        right_gravity = true,
      })
      cell_index = cell_index + 1
    end
  end
end

local function cell_label(cell_type)
  if cell_type == "markdown" then
    return " Markdown cell "
  end

  if cell_type == "raw" then
    return " Raw cell "
  end

  return " Code cell "
end

local function border_text(left, label)
  return left .. label .. string.rep("─", 48)
end

local function refresh_cell_borders(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, display_namespace, 0, -1)

  local marker_lines = {}
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for line_index, line in ipairs(lines) do
    local cell_type = parse_marker(line)
    if cell_type then
      table.insert(marker_lines, { line = line_index - 1, cell_type = cell_type })
      vim.api.nvim_buf_set_extmark(buf, display_namespace, line_index - 1, 0, {
        end_col = #line,
        conceal = "",
        virt_text = { { border_text("╭─", cell_label(cell_type)), "NotebookCellBorder" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end

  for index, marker in ipairs(marker_lines) do
    local next_marker = marker_lines[index + 1]
    local bottom_line = next_marker and math.max(marker.line, next_marker.line - 1) or math.max(marker.line, #lines - 1)
    vim.api.nvim_buf_set_extmark(buf, display_namespace, bottom_line, 0, {
      virt_lines = { { { "╰" .. string.rep("─", 60), "NotebookCellBorder" } } },
      virt_lines_above = false,
    })
  end
end

local function copy(value)
  return vim.deepcopy(value, true)
end

local function new_cell_id(index)
  local seed = ("%s:%s:%s"):format(vim.uv.hrtime(), index, math.random())
  return vim.fn.sha256(seed):sub(1, 8)
end

local function build_cell(parsed, original, index)
  local cell = {}
  local source_style = "array"

  if original then
    cell = copy(original)
    source_style = original._notebook_source_style or cell_source_style(original)
  else
    cell.metadata = vim.empty_dict()
    cell.id = new_cell_id(index)
  end

  cell.cell_type = parsed.cell_type
  cell.source = lines_to_source(parsed.lines, source_style)
  cell.metadata = cell.metadata or vim.empty_dict()

  if parsed.cell_type == "code" then
    cell.outputs = cell.outputs or {}
    if cell.execution_count == nil then
      cell.execution_count = vim.NIL
    end
  else
    cell.outputs = nil
    cell.execution_count = nil
  end

  cell._notebook_source_style = nil

  return cell
end

local function notebook_from_buffer(buf, state)
  local notebook = copy(state.notebook)
  local parsed_cells = parse_cells(vim.api.nvim_buf_get_lines(buf, 0, -1, false), function(line_number)
    return marker_extmark_id(buf, line_number)
  end)
  notebook.cells = {}

  for index, parsed in ipairs(parsed_cells) do
    local original = parsed.marker_id and state.cells[parsed.marker_id] or nil
    table.insert(notebook.cells, build_cell(parsed, original, index))
  end

  return notebook
end

local function prepare_state(notebook, path)
  notebook.cells = notebook.cells or {}

  local cells = {}
  for _, cell in ipairs(notebook.cells) do
    local saved = copy(cell)
    saved._notebook_source_style = cell_source_style(cell)
    table.insert(cells, saved)
  end

  return {
    path = path,
    notebook = notebook,
    cells = cells,
  }
end

local function set_buffer_contents(buf, path, notebook)
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "python", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, render_notebook(notebook))
  set_cell_extmarks(buf, #notebook.cells)
  refresh_cell_borders(buf)
  set_notebook_window_options(buf)
  vim.api.nvim_set_option_value("modified", false, { buf = buf })
  vim.api.nvim_buf_set_name(buf, path)
end

local function set_raw_contents(buf, path, lines)
  state_by_buf[buf] = nil
  raw_fallback_by_buf[buf] = path
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "json", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modified", false, { buf = buf })
  vim.api.nvim_buf_set_name(buf, path)
end

local function validate_notebook(notebook, path)
  if type(notebook) ~= "table" or type(notebook.cells) ~= "table" then
    error(("%s is not a valid notebook: missing cells array"):format(path))
  end

  if not vim.islist(notebook.cells) then
    error(("%s is not a valid notebook: cells must be an array"):format(path))
  end

  for index, cell in ipairs(notebook.cells) do
    if type(cell) ~= "table" then
      error(("%s is not a valid notebook: cell %s is not an object"):format(path, index))
    end

    if cell.cell_type ~= "code" and cell.cell_type ~= "markdown" and cell.cell_type ~= "raw" then
      error(("%s is not a valid notebook: cell %s has unsupported cell_type"):format(path, index))
    end

    if cell.source ~= nil and type(cell.source) ~= "string" and type(cell.source) ~= "table" then
      error(("%s is not a valid notebook: cell %s source must be a string or array"):format(path, index))
    end
  end
end

local function decode_notebook(path)
  local content, read_status = read_file(path)
  if read_status == "missing" then
    return nil, "missing"
  end

  if content:match("^%s*$") then
    return nil, "empty"
  end

  local ok, notebook = pcall(vim.json.decode, content)
  if not ok then
    error(("Unable to parse %s as notebook JSON: %s"):format(path, notebook))
  end

  validate_notebook(notebook, path)

  return notebook
end

local function empty_notebook()
  return {
    cells = {},
    metadata = {
      kernelspec = {
        display_name = "Python 3",
        language = "python",
        name = "python3",
      },
      language_info = {
        name = "python",
      },
    },
    nbformat = 4,
    nbformat_minor = 5,
  }
end

function M.open(path, buf)
  local ok, notebook = pcall(decode_notebook, path)
  if not ok then
    local read_ok, lines = pcall(vim.fn.readfile, path)
    if read_ok then
      set_raw_contents(buf, path, lines)
    end

    notify(("%s; opened raw JSON instead"):format(notebook), vim.log.levels.ERROR)
    return
  end

  if notebook == nil then
    M.new(path, buf)
    return
  end

  state_by_buf[buf] = prepare_state(notebook, path)
  set_buffer_contents(buf, path, notebook)
end

function M.new(path, buf)
  local notebook = empty_notebook()
  raw_fallback_by_buf[buf] = nil
  state_by_buf[buf] = prepare_state(notebook, path)
  set_buffer_contents(buf, path, notebook)
end

function M.write(buf, target_path)
  local state = state_by_buf[buf]
  if not state then
    local raw_path = raw_fallback_by_buf[buf]
    if raw_path then
      local path = target_path or raw_path
      local ok, message = pcall(write_lines, path, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      if not ok then
        notify(message, vim.log.levels.ERROR)
        return
      end

      vim.api.nvim_set_option_value("modified", false, { buf = buf })
      return
    end

    notify("No notebook state is attached to this buffer", vim.log.levels.ERROR)
    return
  end

  local path = target_path or state.path
  local buffer_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
  local updates_current_file = path == state.path or path == buffer_path

  local ok, notebook = pcall(notebook_from_buffer, buf, state)
  if not ok then
    notify(("Notebook write failed: %s"):format(notebook), vim.log.levels.ERROR)
    return
  end

  local encode_ok, encoded = pcall(vim.json.encode, notebook)
  if not encode_ok then
    notify(("Notebook JSON encoding failed: %s"):format(encoded), vim.log.levels.ERROR)
    return
  end

  local write_ok, message = pcall(write_file, path, encoded)
  if not write_ok then
    notify(message, vim.log.levels.ERROR)
    return
  end

  if updates_current_file then
    state_by_buf[buf] = prepare_state(notebook, path)
    set_cell_extmarks(buf, #notebook.cells)
    refresh_cell_borders(buf)
    vim.api.nvim_set_option_value("modified", false, { buf = buf })
  end
end

local function insert_cell(marker)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, { "", marker, "" })
  vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
end

function M.insert_code_cell()
  insert_cell("# %%")
end

function M.insert_markdown_cell()
  insert_cell("# %% [markdown]")
end

function M.open_raw()
  local buf = vim.api.nvim_get_current_buf()
  local state = state_by_buf[buf]
  if not state then
    notify("No notebook state is attached to this buffer", vim.log.levels.ERROR)
    return
  end

  local ok, current_notebook = pcall(notebook_from_buffer, buf, state)
  if not ok then
    notify(("Unable to render raw notebook JSON: %s"):format(current_notebook), vim.log.levels.ERROR)
    return
  end

  local scratch = vim.api.nvim_create_buf(false, true)
  local encoded = vim.json.encode(current_notebook)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(encoded, "\n", { plain = true }))
  vim.api.nvim_set_option_value("filetype", "json", { buf = scratch })
  vim.api.nvim_set_option_value("modifiable", false, { buf = scratch })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = scratch })
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, scratch)
end

local function set_notebook_keymaps(buf)
  local opts = { buffer = buf, silent = true }
  vim.keymap.set(
    "n",
    "<leader>jc",
    M.insert_code_cell,
    vim.tbl_extend("force", opts, { desc = "Notebook code cell" })
  )
  vim.keymap.set(
    "n",
    "<leader>jm",
    M.insert_markdown_cell,
    vim.tbl_extend("force", opts, { desc = "Notebook markdown cell" })
  )
  vim.keymap.set(
    "n",
    "<leader>jJ",
    M.open_raw,
    vim.tbl_extend("force", opts, { desc = "Notebook raw JSON" })
  )
end

function M.setup()
  local group = vim.api.nvim_create_augroup("user-notebook", { clear = true })

  vim.api.nvim_set_hl(0, "NotebookCellBorder", { link = "FloatBorder", default = true })

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = "*.ipynb",
    callback = function(args)
      M.open(vim.fn.fnamemodify(args.file, ":p"), args.buf)
      set_notebook_keymaps(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufNewFile", {
    group = group,
    pattern = "*.ipynb",
    callback = function(args)
      M.new(vim.fn.fnamemodify(args.file, ":p"), args.buf)
      set_notebook_keymaps(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = "*.ipynb",
    callback = function(args)
      M.write(args.buf, vim.fn.fnamemodify(args.file, ":p"))
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    pattern = "*.ipynb",
    callback = function(args)
      state_by_buf[args.buf] = nil
      raw_fallback_by_buf[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "TextChangedI" }, {
    group = group,
    pattern = "*.ipynb",
    callback = function(args)
      if state_by_buf[args.buf] then
        set_notebook_window_options(args.buf)
        refresh_cell_borders(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    pattern = "*.ipynb",
    callback = function()
      vim.api.nvim_set_option_value("conceallevel", vim.o.conceallevel, { win = 0 })
    end,
  })

  vim.api.nvim_create_user_command("NotebookCodeCell", M.insert_code_cell, { desc = "Insert notebook code cell" })
  vim.api.nvim_create_user_command(
    "NotebookMarkdownCell",
    M.insert_markdown_cell,
    { desc = "Insert notebook Markdown cell" }
  )
  vim.api.nvim_create_user_command("NotebookRawJson", M.open_raw, { desc = "Open raw notebook JSON scratch" })
end

M._test = {
  parse_cells = parse_cells,
  render_notebook = render_notebook,
}

return M
