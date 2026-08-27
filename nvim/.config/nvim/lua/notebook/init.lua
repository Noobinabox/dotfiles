local M = {}

local state_by_buf = {}
local raw_fallback_by_buf = {}
local identity_namespace = vim.api.nvim_create_namespace("user-notebook-identity")
local display_namespace = vim.api.nvim_create_namespace("user-notebook-display")
local content_prefix = "│  "

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
    return " Markdown "
  end

  if cell_type == "raw" then
    return " Raw "
  end

  return " Code "
end

local function notebook_window_geometry(buf)
  local fallback_width = math.max(32, vim.o.columns - 8)
  local fallback_right_column = math.max(0, fallback_width - 1)

  local function geometry_for_win(win)
    local info = vim.fn.getwininfo(win)[1] or {}
    local textoff = info.textoff or 0
    local width = math.max(32, vim.api.nvim_win_get_width(win) - textoff - 2)

    return {
      width = width,
      right_column = width - 1,
    }
  end

  local current_win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_is_valid(current_win) and vim.api.nvim_win_get_buf(current_win) == buf then
    return geometry_for_win(current_win)
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return geometry_for_win(win)
    end
  end

  return {
    width = fallback_width,
    right_column = fallback_right_column,
  }
end

local function notebook_window_width(buf)
  return notebook_window_geometry(buf).width
end

local function border_text(left, label, width)
  local right = "╮"
  local text = left .. label

  while vim.fn.strdisplaywidth(text .. right) < width do
    text = text .. "─"
  end

  return text .. right
end

local function bottom_border_text(width)
  local right = "╯"
  local text = "╰"

  while vim.fn.strdisplaywidth(text .. right) < width do
    text = text .. "─"
  end

  return text .. right
end

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function next_inline_match(text, start)
  local patterns = {
    { kind = "image", pattern = "!%[([^%]]+)%]%([^%)]+%)" },
    { kind = "link", pattern = "%[([^%]]+)%]%([^%)]+%)" },
    { kind = "code", pattern = "`([^`]+)`" },
    { kind = "bold", pattern = "%*%*([^*]+)%*%*" },
    { kind = "bold", pattern = "__([^_]+)__" },
    { kind = "italic", pattern = "%*([^*]+)%*" },
    { kind = "italic", pattern = "_([^_]+)_" },
  }
  local best = nil

  for _, candidate in ipairs(patterns) do
    local match_start, match_end, capture = text:find(candidate.pattern, start)
    if match_start and (not best or match_start < best.match_start) then
      best = {
        kind = candidate.kind,
        match_start = match_start,
        match_end = match_end,
        capture = capture,
      }
    end
  end

  return best
end

local function apply_conceal(buf, line_number, start_col, end_col)
  if start_col < end_col then
    vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, start_col, {
      end_col = end_col,
      conceal = "",
      hl_mode = "combine",
    })
  end
end

local function apply_inline_markdown_conceal(buf, line_number, line, offset)
  local position = 1
  local column_offset = offset or 0

  while position <= #line do
    local match = next_inline_match(line, position)
    if not match then
      break
    end

    if match.kind == "code" then
      apply_conceal(buf, line_number, column_offset + match.match_start - 1, column_offset + match.match_start)
      apply_conceal(buf, line_number, column_offset + match.match_end - 1, column_offset + match.match_end)
      vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, column_offset + match.match_start, {
        end_col = column_offset + match.match_end - 1,
        hl_group = "NotebookMarkdownCode",
      })
    elseif match.kind == "bold" then
      apply_conceal(buf, line_number, column_offset + match.match_start - 1, column_offset + match.match_start + 1)
      apply_conceal(buf, line_number, column_offset + match.match_end - 2, column_offset + match.match_end)
      vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, column_offset + match.match_start + 1, {
        end_col = column_offset + match.match_end - 2,
        hl_group = "NotebookMarkdownStrong",
      })
    elseif match.kind == "italic" then
      apply_conceal(buf, line_number, column_offset + match.match_start - 1, column_offset + match.match_start)
      apply_conceal(buf, line_number, column_offset + match.match_end - 1, column_offset + match.match_end)
      vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, column_offset + match.match_start, {
        end_col = column_offset + match.match_end - 1,
        hl_group = "NotebookMarkdownEmphasis",
      })
    elseif match.kind == "link" or match.kind == "image" then
      vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, column_offset + match.match_start - 1, {
        end_col = column_offset + match.match_end,
        hl_group = "NotebookMarkdownLink",
      })
    end

    position = match.match_end + 1
  end
end

local function markdown_display_source(line)
  if line == "#" then
    return "", 1
  end

  if vim.startswith(line, "# ") then
    return line:sub(3), 2
  end

  if vim.startswith(line, "#") then
    return line:sub(2), 1
  end

  return line, 0
end

local function apply_markdown_highlights(buf, line_number, line, in_fenced_code)
  local source, source_offset = markdown_display_source(line)
  apply_conceal(buf, line_number, 0, source_offset)

  if source == "" then
    return
  end

  if source:match("^%s*```") or in_fenced_code then
    vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, source_offset, {
      end_col = #line,
      hl_group = "NotebookMarkdownCode",
    })
    return
  end

  local hashes, heading_text = source:match("^(#+)(%s+.+)$")
  if hashes and #hashes <= 6 then
    apply_conceal(buf, line_number, source_offset, source_offset + #hashes + 1)
    vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, source_offset + #hashes + 1, {
      end_col = source_offset + #hashes + #heading_text,
      hl_group = #hashes == 1 and "NotebookMarkdownH1" or "NotebookMarkdownHeading",
    })
    apply_inline_markdown_conceal(buf, line_number, source, source_offset)
    return
  end

  if source:match("^%s*[-*_][%-*_][%-*_]+%s*$") then
    vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, source_offset, {
      end_col = #line,
      conceal = string.rep("─", 36),
      hl_group = "NotebookMarkdownRule",
    })
    return
  end

  apply_inline_markdown_conceal(buf, line_number, source, source_offset)
end

local function apply_right_border(buf, line_number, column)
  vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, 0, {
    virt_text = { { "│", "NotebookCellBorder" } },
    virt_text_win_col = math.max(0, column),
    hl_mode = "combine",
  })
end

local function apply_markdown_render(buf, line_number, line, right_column, in_fenced_code)
  vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, 0, {
    virt_text = { { content_prefix, "NotebookCellBorder" } },
    virt_text_pos = "inline",
    hl_mode = "combine",
  })
  apply_markdown_highlights(buf, line_number, line, in_fenced_code)
  apply_right_border(buf, line_number, right_column)
end

local function apply_cell_content_prefix(buf, line_number, right_column)
  vim.api.nvim_buf_set_extmark(buf, display_namespace, line_number, 0, {
    virt_text = { { content_prefix, "NotebookCellBorder" } },
    virt_text_pos = "inline",
    hl_mode = "combine",
  })
  apply_right_border(buf, line_number, right_column)
end

local function refresh_cell_borders(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, display_namespace, 0, -1)

  local cells = {}
  local current_cell = nil
  local geometry = notebook_window_geometry(buf)
  local cell_width = geometry.width
  local right_column = geometry.right_column
  local in_fenced_code = false
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for line_index, line in ipairs(lines) do
    local cell_type = parse_marker(line)
    if cell_type then
      current_cell = { line = line_index - 1, cell_type = cell_type }
      in_fenced_code = false
      table.insert(cells, current_cell)
      vim.api.nvim_buf_set_extmark(buf, display_namespace, line_index - 1, 0, {
        end_col = #line,
        conceal = "",
        virt_text = { { border_text("╭─", cell_label(cell_type), cell_width), "NotebookCellBorder" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    elseif current_cell then
      if current_cell.cell_type == "markdown" then
        apply_markdown_render(buf, line_index - 1, line, right_column, in_fenced_code)
        if parse_markdown_line(line):match("^%s*```") then
          in_fenced_code = not in_fenced_code
        end
      else
        apply_cell_content_prefix(buf, line_index - 1, right_column)
      end
    end
  end

  for index, marker in ipairs(cells) do
    local next_marker = cells[index + 1]
    local bottom_line = next_marker and math.max(marker.line, next_marker.line - 1) or math.max(marker.line, #lines - 1)
    vim.api.nvim_buf_set_extmark(buf, display_namespace, bottom_line, 0, {
      virt_lines = { { { bottom_border_text(cell_width), "NotebookCellBorder" } } },
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

local function find_cell_bounds(lines, cursor_line)
  local start_line = nil
  local next_start_line = nil

  for index, line in ipairs(lines) do
    local line_number = index - 1
    if parse_marker(line) then
      if line_number <= cursor_line then
        start_line = line_number
      elseif not next_start_line then
        next_start_line = line_number
        break
      end
    end
  end

  return start_line or 0, next_start_line
end

local function insert_cell(marker, placement)
  local buf = vim.api.nvim_get_current_buf()
  if not state_by_buf[buf] then
    notify("No notebook state is attached to this buffer", vim.log.levels.ERROR)
    return
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cell_start, next_cell_start = find_cell_bounds(lines, cursor_line)
  local insert_line = nil
  local new_cursor_line = nil

  if placement == "above" then
    insert_line = cell_start
    vim.api.nvim_buf_set_lines(buf, insert_line, insert_line, false, { marker, "" })
    new_cursor_line = insert_line + 1
  else
    insert_line = next_cell_start or #lines
    local has_separator = insert_line > 0 and lines[insert_line] == ""
    local inserted_lines = has_separator and { marker, "" } or { "", marker, "" }
    vim.api.nvim_buf_set_lines(buf, insert_line, insert_line, false, inserted_lines)
    new_cursor_line = insert_line + (has_separator and 1 or 2)
  end

  vim.api.nvim_win_set_cursor(0, { new_cursor_line + 1, 0 })
  refresh_cell_borders(buf)
end

function M.insert_code_cell()
  insert_cell("# %%", "below")
end

function M.insert_code_cell_above()
  insert_cell("# %%", "above")
end

function M.insert_markdown_cell()
  insert_cell("# %% [markdown]", "below")
end

function M.insert_markdown_cell_above()
  insert_cell("# %% [markdown]", "above")
end

function M.insert_raw_cell()
  insert_cell("# %% [raw]", "below")
end

function M.insert_raw_cell_above()
  insert_cell("# %% [raw]", "above")
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
    "<leader>jC",
    M.insert_code_cell_above,
    vim.tbl_extend("force", opts, { desc = "Notebook code cell above" })
  )
  vim.keymap.set(
    "n",
    "<leader>jm",
    M.insert_markdown_cell,
    vim.tbl_extend("force", opts, { desc = "Notebook markdown cell" })
  )
  vim.keymap.set(
    "n",
    "<leader>jM",
    M.insert_markdown_cell_above,
    vim.tbl_extend("force", opts, { desc = "Notebook markdown cell above" })
  )
  vim.keymap.set(
    "n",
    "<leader>jr",
    M.insert_raw_cell,
    vim.tbl_extend("force", opts, { desc = "Notebook raw cell" })
  )
  vim.keymap.set(
    "n",
    "<leader>jR",
    M.insert_raw_cell_above,
    vim.tbl_extend("force", opts, { desc = "Notebook raw cell above" })
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
  vim.api.nvim_set_hl(0, "NotebookMarkdown", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownH1", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownHeading", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownListMarker", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownQuote", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownCode", { link = "String", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownRule", { link = "FloatBorder", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownStrong", { bold = true, default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownEmphasis", { italic = true, default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownLink", { link = "Underlined", default = true })

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

  vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "TextChangedI", "WinEnter" }, {
    group = group,
    pattern = "*.ipynb",
    callback = function(args)
      if state_by_buf[args.buf] then
        set_notebook_window_options(args.buf)
        refresh_cell_borders(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = group,
    callback = function()
      for buf in pairs(state_by_buf) do
        refresh_cell_borders(buf)
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
    "NotebookCodeCellAbove",
    M.insert_code_cell_above,
    { desc = "Insert notebook code cell above" }
  )
  vim.api.nvim_create_user_command(
    "NotebookMarkdownCell",
    M.insert_markdown_cell,
    { desc = "Insert notebook Markdown cell" }
  )
  vim.api.nvim_create_user_command(
    "NotebookMarkdownCellAbove",
    M.insert_markdown_cell_above,
    { desc = "Insert notebook Markdown cell above" }
  )
  vim.api.nvim_create_user_command("NotebookRawCell", M.insert_raw_cell, { desc = "Insert notebook raw cell" })
  vim.api.nvim_create_user_command(
    "NotebookRawCellAbove",
    M.insert_raw_cell_above,
    { desc = "Insert notebook raw cell above" }
  )
  vim.api.nvim_create_user_command("NotebookRawJson", M.open_raw, { desc = "Open raw notebook JSON scratch" })
end

M._test = {
  display_namespace = display_namespace,
  find_cell_bounds = find_cell_bounds,
  notebook_window_width = notebook_window_width,
  parse_cells = parse_cells,
  refresh_cell_borders = refresh_cell_borders,
  render_notebook = render_notebook,
}

return M
