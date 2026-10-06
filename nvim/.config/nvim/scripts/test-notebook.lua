local notebook = require("notebook")
local temp = nil
local invalid = nil
local alternate = nil
local saveas = nil
local missing = nil
local empty = nil
local private = nil
local symlink_target = nil
local symlink_link = nil
local malformed = nil
local insertion = nil
local titled = nil
local title_edit = nil

local function fail(message)
  if temp then
    vim.fn.delete(temp)
  end

  if invalid then
    vim.fn.delete(invalid)
  end

  if alternate then
    vim.fn.delete(alternate)
  end

  if saveas then
    vim.fn.delete(saveas)
  end

  if missing then
    vim.fn.delete(missing)
  end

  if empty then
    vim.fn.delete(empty)
  end

  if private then
    vim.fn.delete(private)
  end

  if symlink_link then
    vim.fn.delete(symlink_link)
  end

  if symlink_target then
    vim.fn.delete(symlink_target)
  end

  if malformed then
    vim.fn.delete(malformed)
  end

  if insertion then
    vim.fn.delete(insertion)
  end

  if titled then
    vim.fn.delete(titled)
  end
  if title_edit then
    vim.fn.delete(title_edit)
  end

  error(message, 0)
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    fail(("%s: expected %s, got %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_match(actual, pattern, message)
  if not tostring(actual):match(pattern) then
    fail(("%s: expected %s to match %s"):format(message, vim.inspect(actual), vim.inspect(pattern)))
  end
end

local function extmark_text(mark)
  local details = mark[4] or {}
  local text = {}

  for _, chunk in ipairs(details.virt_text or {}) do
    table.insert(text, chunk[1])
  end

  for _, line in ipairs(details.virt_lines or {}) do
    for _, chunk in ipairs(line) do
      table.insert(text, chunk[1])
    end
  end

  return table.concat(text, "")
end

temp = vim.fn.tempname() .. ".ipynb"
local original = {
  cells = {
    {
      cell_type = "code",
      execution_count = 7,
      id = "code-1",
      metadata = {
        tags = { "keep" },
        ["application/vnd.databricks.v1+cell"] = { title = "Read input", showTitle = true },
      },
      outputs = {
        {
          name = "stdout",
          output_type = "stream",
          text = { "old output\n" },
        },
      },
      source = { "print('old')\n" },
    },
    {
      cell_type = "markdown",
      id = "markdown-1",
      metadata = {},
      source = "# Heading\n\nDetails",
    },
  },
  metadata = { custom = "metadata" },
  nbformat = 4,
  nbformat_minor = 5,
}

vim.fn.writefile({ vim.json.encode(original) }, temp)
vim.wo.conceallevel = 1
vim.wo.concealcursor = "v"
vim.cmd.edit(vim.fn.fnameescape(temp))

local buf = vim.api.nvim_get_current_buf()
local rendered = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
assert_equal(vim.bo[buf].filetype, "python", "notebook buffer filetype")
assert_equal(vim.wo.concealcursor, "nc", "notebook conceals current marker in Normal mode")

if rendered[1] ~= "# %%" or rendered[2] ~= "print('old')" or rendered[4] ~= "# %% [markdown]" then
  fail("notebook did not render as percent-cell Python")
end
assert_equal(rendered[5], "# # Heading", "markdown heading is stored as a Python comment")
assert_equal(rendered[7], "# Details", "markdown cell stores body as Python comment")

local display_marks = vim.api.nvim_buf_get_extmarks(buf, notebook._test.display_namespace, 0, -1, { details = true })
local display_text = {}
for _, mark in ipairs(display_marks) do
  table.insert(display_text, extmark_text(mark))
end
local display_summary = table.concat(display_text, "\n")
assert_match(display_summary, "╭─ Code", "code cell has a rendered top border")
assert_match(display_summary, "Code — Read input", "code cell displays its saved Databricks title")
assert_match(display_summary, "│  ", "code cell content receives cell padding")
assert_match(display_summary, "╭─ Markdown", "markdown cell has a rendered top border")
assert_match(display_summary, "╰─", "cells have rendered bottom borders")

local expected_cell_width = notebook._test.notebook_window_width(buf)
local right_border_column = expected_cell_width - 1
local has_right_border = false
local has_aligned_top_border = false
local has_aligned_bottom_border = false
for _, mark in ipairs(display_marks) do
  local details = mark[4] or {}
  local text = extmark_text(mark)
  if details.virt_text_win_col == right_border_column and text == "│" then
    has_right_border = true
  elseif text:match("^╭") and text:match("Code") and vim.fn.strdisplaywidth(text) == expected_cell_width then
    assert_equal(details.virt_lines_above, true, "cell title has its own virtual row")
    assert_equal(details.virt_text, nil, "cell title does not overlay the cursor line")
    has_aligned_top_border = true
  elseif text:match("^╰") and vim.fn.strdisplaywidth(text) == expected_cell_width then
    has_aligned_bottom_border = true
  end
end
assert_equal(has_right_border, true, "cell right border is aligned to the cell edge")
assert_equal(has_aligned_top_border, true, "cell top border spans the right border column")
assert_equal(has_aligned_bottom_border, true, "cell bottom border spans the right border column")

local ui_channel = vim.fn.jobstart({ vim.v.progpath, "--embed", "--clean", "-n", "-i", "NONE" }, { rpc = true })
if ui_channel <= 0 then
  fail("unable to start isolated notebook UI")
end
local ui_ok, ui_result = pcall(function()
  vim.rpcrequest(ui_channel, "nvim_ui_attach", 80, 12, { rgb = true })
  local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  local initial = vim.rpcrequest(ui_channel, "nvim_exec_lua", [[
    local config_root, path = ...
    vim.opt.rtp:append(config_root)
    require("notebook").setup()
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim__redraw({ flush = true, valid = false })
    local cursor = vim.fn.screenpos(0, 1, 1)
    local function screen_row(row)
      local text = ""
      for col = 1, 80 do
        text = text .. vim.fn.screenstring(row, col)
      end
      return text
    end
    return { row = cursor.row, header = screen_row(cursor.row - 1), marker = screen_row(cursor.row) }
  ]], { config_root, temp })
  vim.rpcrequest(ui_channel, "nvim_exec_lua", [[
    local lines = {}
    for i = 1, 50 do
      lines[i] = "# More notebook content " .. i
    end
    vim.api.nvim_buf_set_lines(0, -1, -1, false, lines)
  ]], {})
  local capture_bottom = [[
    vim.api.nvim__redraw({ flush = true, valid = false })
    local last_line = vim.api.nvim_buf_line_count(0)
    local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    local bottom_row = info.winrow + info.height - 1
    local text = ""
    for col = 1, 80 do
      text = text .. vim.fn.screenstring(bottom_row, col)
    end
    return {
      bottom_row = text, cursor_line = vim.fn.line("."), last_line = last_line,
      cursor_row = vim.fn.screenpos(0, last_line, vim.fn.col(".")).row,
      window_bottom = bottom_row,
      mode = vim.fn.mode(),
    }
  ]]
  vim.rpcrequest(ui_channel, "nvim_input", "G")
  local after_end = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_bottom, {})
  vim.rpcrequest(ui_channel, "nvim_input", "zb")
  local after_bottom_scroll = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_bottom, {})
  vim.rpcrequest(ui_channel, "nvim_exec_lua", [[
    vim.api.nvim_buf_set_lines(0, 3, 4, false, { "# %%" })
    vim.api.nvim_buf_set_lines(0, -2, -1, false, { string.rep("wrapped code ", 15) })
  ]], {})
  vim.rpcrequest(ui_channel, "nvim_input", "gg")
  vim.rpcrequest(ui_channel, "nvim_eval", "line('.')")
  vim.rpcrequest(ui_channel, "nvim_input", "G")
  local wrapped_end = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_bottom, {})
  vim.rpcrequest(ui_channel, "nvim_exec_lua", [[
    vim.api.nvim_buf_set_lines(0, -2, -1, false, { "" })
  ]], {})
  vim.rpcrequest(ui_channel, "nvim_input", "gg")
  vim.rpcrequest(ui_channel, "nvim_eval", "line('.')")
  vim.rpcrequest(ui_channel, "nvim_input", "G")
  local blank_end = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_bottom, {})
  vim.rpcrequest(ui_channel, "nvim_input", "gg")
  vim.rpcrequest(ui_channel, "nvim_eval", "line('.')")
  vim.rpcrequest(ui_channel, "nvim_input", "vG")
  local visual_end = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_bottom, {})
  vim.rpcrequest(ui_channel, "nvim_input", vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
  vim.rpcrequest(ui_channel, "nvim_input", "gg")
  local capture_top = [[
    vim.api.nvim__redraw({ flush = true, valid = false })
    local cursor = vim.fn.screenpos(0, 1, 1)
    local text = ""
    for col = 1, 80 do
      text = text .. vim.fn.screenstring(1, col)
    end
    return { row = cursor.row, top_row = text, view = vim.fn.winsaveview() }
  ]]
  local after_navigation = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_top, {})
  vim.rpcrequest(ui_channel, "nvim_input", "zt")
  local after_scroll = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_top, {})
  vim.rpcrequest(ui_channel, "nvim_exec_lua", [[
    vim.api.nvim_buf_set_lines(0, 0, 1, false, { "# %% [markdown]" })
  ]], {})
  vim.rpcrequest(ui_channel, "nvim_input", "G")
  vim.rpcrequest(ui_channel, "nvim_eval", "line('.')")
  vim.rpcrequest(ui_channel, "nvim_input", "gg")
  local markdown_navigation = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_top, {})
  vim.rpcrequest(ui_channel, "nvim_exec_lua", [[
    vim.cmd.enew({ bang = true })
    local lines = {}
    for i = 1, 50 do lines[i] = "Ordinary text " .. i end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace("test-ordinary-header"), 0, 0, {
      virt_lines = { { { "Ordinary virtual header", "Normal" } } }, virt_lines_above = true,
    })
  ]], {})
  vim.rpcrequest(ui_channel, "nvim_input", "G")
  vim.rpcrequest(ui_channel, "nvim_eval", "line('.')")
  vim.rpcrequest(ui_channel, "nvim_input", "gg")
  local ordinary_navigation = vim.rpcrequest(ui_channel, "nvim_exec_lua", capture_top, {})
  return {
    initial = initial,
    after_end = after_end,
    after_bottom_scroll = after_bottom_scroll,
    wrapped_end = wrapped_end,
    blank_end = blank_end,
    visual_end = visual_end,
    after_navigation = after_navigation,
    after_scroll = after_scroll,
    markdown_navigation = markdown_navigation,
    ordinary_navigation = ordinary_navigation,
  }
end)
vim.fn.jobstop(ui_channel)
vim.fn.jobwait({ ui_channel }, 1000)
if not ui_ok then
  fail("notebook UI probe failed: " .. tostring(ui_result))
end
assert_equal(ui_result.initial.row > 1, true, "cursor occupies a row below the title")
assert_match(ui_result.initial.header, "Code — Read input", "first cell title remains visible above cursor")
assert_equal(ui_result.initial.marker:find("Read input", 1, true), nil, "cursor row contains no title text")
assert_equal(ui_result.initial.marker:find("# %%", 1, true), nil, "cursor row hides the raw cell marker")
assert_match(ui_result.after_end.bottom_row, "^╰─", "G keeps final cell closing border visible")
assert_equal(ui_result.after_end.cursor_line, ui_result.after_end.last_line, "G still targets the final buffer line")
assert_equal(ui_result.after_end.cursor_row < ui_result.after_end.window_bottom, true, "G leaves cursor above final border")
assert_match(ui_result.after_bottom_scroll.bottom_row, "^╰─", "zb keeps final border visible without cursor movement")
assert_match(ui_result.wrapped_end.bottom_row, "^╰─", "wrapped final code line keeps closing border visible")
assert_equal(ui_result.wrapped_end.cursor_line, ui_result.wrapped_end.last_line, "wrapped code footer correction preserves cursor line")
assert_match(ui_result.blank_end.bottom_row, "^╰─", "blank final code line keeps closing border visible")
assert_equal(ui_result.visual_end.mode, "v", "footer scrolling preserves Visual selection mode")
assert_equal(ui_result.visual_end.cursor_line, ui_result.visual_end.last_line, "Visual G keeps selection endpoint on final line")
assert_equal(ui_result.after_navigation.row > 1, true, "G then gg leaves room for the first header")
assert_match(ui_result.after_navigation.top_row, "Code — Read input", "G then gg keeps the first header visible")
assert_match(ui_result.after_scroll.top_row, "Code — Read input", "zt keeps header visible without cursor movement")
assert_match(ui_result.markdown_navigation.top_row, "^╭─ Markdown ", "G then gg keeps first Markdown header visible")
assert_equal(ui_result.markdown_navigation.row > 1, true, "first Markdown header stays separate from cursor")
assert_equal(ui_result.ordinary_navigation.view.topfill, 0, "ordinary buffers keep their own scroll behavior")

vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.signcolumn = "yes"
notebook._test.refresh_cell_borders(buf)
display_marks = vim.api.nvim_buf_get_extmarks(buf, notebook._test.display_namespace, 0, -1, { details = true })
expected_cell_width = notebook._test.notebook_window_width(buf)
right_border_column = expected_cell_width - 1
has_right_border = false
for _, mark in ipairs(display_marks) do
  local details = mark[4] or {}
  if details.virt_text_win_col == right_border_column and extmark_text(mark) == "│" then
    has_right_border = true
    break
  end
end
assert_equal(has_right_border, true, "cell right border stays inside text area with number and sign columns")

vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "print('new')" })
vim.api.nvim_buf_set_lines(buf, 4, -1, false, {
  "# # Heading",
  "#",
  "# Changed details",
  "",
  "# %%",
  "value = 42",
})

vim.cmd.write()

local saved = vim.json.decode(table.concat(vim.fn.readfile(temp), "\n"))
assert_equal(saved.metadata.custom, "metadata", "notebook metadata is preserved")
assert_equal(saved.cells[1].metadata["application/vnd.databricks.v1+cell"].title, "Read input", "cell title is preserved on save")
assert_equal(#saved.cells, 3, "cell count")
assert_equal(saved.cells[1].cell_type, "code", "first cell type")
assert_equal(saved.cells[1].id, "code-1", "first cell id")
assert_equal(saved.cells[1].execution_count, 7, "execution count is preserved")
assert_equal(saved.cells[1].outputs[1].text[1], "old output\n", "outputs are preserved")
assert_equal(table.concat(saved.cells[1].source), "print('new')", "code source is updated")
assert_equal(saved.cells[2].cell_type, "markdown", "second cell type")
assert_equal(saved.cells[2].source, "# Heading\n\nChanged details", "markdown source is updated")
assert_equal(saved.cells[3].cell_type, "code", "new cell type")
assert_equal(table.concat(saved.cells[3].source), "value = 42", "new cell source")

vim.api.nvim_buf_set_lines(buf, 0, 0, false, {
  "# %%",
  "fresh = True",
  "",
})
vim.cmd.write()

saved = vim.json.decode(table.concat(vim.fn.readfile(temp), "\n"))
assert_equal(#saved.cells, 4, "cell count after front insertion")
assert_equal(saved.cells[1].cell_type, "code", "inserted front cell type")
assert_equal(saved.cells[1].outputs and #saved.cells[1].outputs or 0, 0, "inserted front cell has no copied outputs")
assert_equal(saved.cells[2].id, "code-1", "original first cell id follows its marker")
assert_equal(saved.cells[2].execution_count, 7, "original first cell execution count follows its marker")
assert_equal(saved.cells[2].outputs[1].text[1], "old output\n", "original first cell outputs follow its marker")

alternate = vim.fn.tempname() .. ".ipynb"
vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "fresh = False" })
vim.cmd.write(vim.fn.fnameescape(alternate))

local original_after_alternate_write = vim.json.decode(table.concat(vim.fn.readfile(temp), "\n"))
local alternate_saved = vim.json.decode(table.concat(vim.fn.readfile(alternate), "\n"))
assert_equal(table.concat(original_after_alternate_write.cells[1].source), "fresh = True", "alternate write keeps original unchanged")
assert_equal(table.concat(alternate_saved.cells[1].source), "fresh = False", "alternate write creates requested target")

saveas = vim.fn.tempname() .. ".ipynb"
vim.cmd.saveas(vim.fn.fnameescape(saveas))
vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "fresh = 'saveas'" })
vim.cmd.write()

local saveas_saved = vim.json.decode(table.concat(vim.fn.readfile(saveas), "\n"))
assert_equal(table.concat(saveas_saved.cells[1].source), "fresh = 'saveas'", "saveas updates new buffer target")

local parsed = notebook._test.parse_cells({ "print('implicit')" })
assert_equal(parsed[1].cell_type, "code", "implicit first cell")
assert_equal(parsed[1].lines[1], "print('implicit')", "implicit first cell source")

local markdown_marker_text = notebook._test.parse_cells({ "# %% [markdown]", "# # %% Results" })
assert_equal(#markdown_marker_text, 1, "markdown text resembling a cell marker does not split cells")
assert_equal(markdown_marker_text[1].lines[1], "# %% Results", "markdown marker-looking text is preserved")

local title_cases = {
  { metadata = { title = " Generic\n\tTitle " }, expected = " Code — Generic Title " },
  { metadata = { title = "\t\n " }, expected = " Code " },
  { metadata = { title = 42 }, expected = " Code " },
  { metadata = vim.NIL, expected = " Code " },
  { metadata = { ["application/vnd.databricks.v1+cell"] = false }, expected = " Code " },
  { metadata = { ["application/vnd.databricks.v1+cell"] = { title = "Hidden", showTitle = false } }, expected = " Code " },
  {
    metadata = { title = "Fallback", ["application/vnd.databricks.v1+cell"] = { title = "Databricks" } },
    expected = " Code — Databricks ",
  },
  {
    metadata = { title = "Fallback", ["application/vnd.databricks.v1+cell"] = { title = vim.NIL } },
    expected = " Code — Fallback ",
  },
}
for _, case in ipairs(title_cases) do
  assert_equal(notebook._test.cell_label("code", { metadata = case.metadata }), case.expected, "cell title fallback and sanitization")
end
assert_equal(notebook._test.cell_label("markdown", { metadata = { title = "Summary" } }), " Markdown — Summary ", "markdown cell title")
assert_equal(notebook._test.cell_label("raw", { metadata = { title = "Notes" } }), " Raw — Notes ", "raw cell title")

titled = vim.fn.tempname() .. ".ipynb"
local long_title_notebook = vim.deepcopy(original)
local long_title = string.rep("資料 🐍 ", 100)
long_title_notebook.cells[1].metadata["application/vnd.databricks.v1+cell"].title = long_title
vim.fn.writefile({ vim.json.encode(long_title_notebook) }, titled)
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(titled))
local titled_buf = vim.api.nvim_get_current_buf()
local titled_marks = vim.api.nvim_buf_get_extmarks(titled_buf, notebook._test.display_namespace, 0, -1, { details = true })
local found_title = false
for _, mark in ipairs(titled_marks) do
  local text = extmark_text(mark)
  if text:match("^╭") and text:match("Code") then
    assert_match(text, "資料", "Unicode title is displayed")
    assert_match(text, "…", "long cell title is clipped")
    assert_equal(vim.fn.strdisplaywidth(text), notebook._test.notebook_window_width(titled_buf), "long title preserves border width")
    found_title = true
  end
end
assert_equal(found_title, true, "long titled cell has a header")
vim.cmd.write()
local titled_saved = vim.json.decode(table.concat(vim.fn.readfile(titled), "\n"))
assert_equal(titled_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].title, long_title, "display truncation does not change saved title")
assert_equal(table.concat(titled_saved.cells[1].source), "print('old')", "title is not injected into source")

insertion = vim.fn.tempname() .. ".ipynb"
vim.fn.writefile({ vim.json.encode(original) }, insertion)
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(insertion))

vim.api.nvim_win_set_cursor(0, { 2, 0 })
notebook.insert_markdown_cell()
vim.api.nvim_buf_set_lines(0, 4, 5, false, { "# Inserted below" })
vim.cmd.write()

local insertion_saved = vim.json.decode(table.concat(vim.fn.readfile(insertion), "\n"))
assert_equal(#insertion_saved.cells, 3, "below insertion adds one cell")
assert_equal(insertion_saved.cells[1].cell_type, "code", "below insertion keeps current code cell first")
assert_equal(table.concat(insertion_saved.cells[1].source), "print('old')", "below insertion preserves current cell source")
assert_equal(insertion_saved.cells[2].cell_type, "markdown", "below insertion adds requested markdown cell")
assert_equal(table.concat(insertion_saved.cells[2].source), "Inserted below", "below insertion saves markdown source")
assert_equal(insertion_saved.cells[3].id, "markdown-1", "below insertion keeps following cell identity")

vim.api.nvim_win_set_cursor(0, { 7, 0 })
notebook.insert_code_cell_above()
vim.api.nvim_buf_set_lines(0, 6, 7, false, { "inserted_above = True" })
vim.cmd.write()

insertion_saved = vim.json.decode(table.concat(vim.fn.readfile(insertion), "\n"))
assert_equal(#insertion_saved.cells, 4, "above insertion adds one cell")
assert_equal(insertion_saved.cells[3].cell_type, "code", "above insertion adds requested code cell")
assert_equal(table.concat(insertion_saved.cells[3].source), "inserted_above = True", "above insertion saves code source")
assert_equal(insertion_saved.cells[4].id, "markdown-1", "above insertion keeps target cell identity after inserted cell")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
notebook.insert_raw_cell()
vim.api.nvim_buf_set_lines(0, 4, 5, false, { "# | raw payload" })
vim.cmd.write()

insertion_saved = vim.json.decode(table.concat(vim.fn.readfile(insertion), "\n"))
assert_equal(#insertion_saved.cells, 5, "raw insertion adds one cell")
assert_equal(insertion_saved.cells[2].cell_type, "raw", "raw insertion adds requested raw cell")
assert_equal(table.concat(insertion_saved.cells[2].source), "raw payload", "raw insertion saves raw source")
assert_equal(insertion_saved.cells[3].cell_type, "markdown", "raw insertion keeps following markdown insertion")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
notebook.insert_markdown_cell_above()
vim.api.nvim_buf_set_lines(0, 1, 2, false, { "# First cell" })
notebook._test.refresh_cell_borders(vim.api.nvim_get_current_buf())
local moved_marks = vim.api.nvim_buf_get_extmarks(0, notebook._test.display_namespace, 0, -1, { details = true })
local moved_title = false
for _, mark in ipairs(moved_marks) do
  local text = extmark_text(mark)
  if text:find("Read input", 1, true) then
    assert_equal(mark[2], 2, "title moves with original cell before save")
    assert_match(text, "Code — Read input", "new cell does not inherit the original title")
    moved_title = true
  end
end
assert_equal(moved_title, true, "titled cell remains labeled after insertion")
vim.cmd.write()

insertion_saved = vim.json.decode(table.concat(vim.fn.readfile(insertion), "\n"))
assert_equal(#insertion_saved.cells, 6, "above-first insertion adds one cell")
assert_equal(insertion_saved.cells[1].cell_type, "markdown", "above-first insertion adds requested markdown cell")
assert_equal(table.concat(insertion_saved.cells[1].source), "First cell", "above-first insertion saves markdown source")
assert_equal(insertion_saved.cells[2].metadata["application/vnd.databricks.v1+cell"].title, "Read input", "title follows original cell on save")

vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })
notebook.insert_code_cell()
vim.api.nvim_buf_set_lines(0, vim.api.nvim_buf_line_count(0) - 1, vim.api.nvim_buf_line_count(0), false, { "last_cell = True" })
vim.cmd.write()

insertion_saved = vim.json.decode(table.concat(vim.fn.readfile(insertion), "\n"))
assert_equal(#insertion_saved.cells, 7, "below-last insertion adds one cell")
assert_equal(insertion_saved.cells[7].cell_type, "code", "below-last insertion adds requested code cell")
assert_equal(table.concat(insertion_saved.cells[7].source), "last_cell = True", "below-last insertion saves code source")

vim.cmd.enew()
assert_equal(vim.wo.conceallevel, 1, "leaving notebook restores prior conceal level")
assert_equal(vim.wo.concealcursor, "v", "leaving notebook restores prior cursor conceal modes")

local function prompt_title(value, action)
  local saved_input = vim.ui.input
  local options = nil
  vim.ui.input = function(opts, callback)
    options = opts
    callback(value)
  end
  local ok, err = pcall(action or notebook.edit_cell_title)
  vim.ui.input = saved_input
  if not ok then
    fail(err)
  end
  return options
end

title_edit = vim.fn.tempname() .. ".ipynb"
vim.fn.writefile({ vim.json.encode(original) }, title_edit)
vim.cmd.edit(vim.fn.fnameescape(title_edit))
local title_buf = vim.api.nvim_get_current_buf()
vim.api.nvim_win_set_cursor(0, { 2, 0 })
local title_keymap = vim.fn.maparg("<leader>jt", "n", false, true)
assert_equal(title_keymap.buffer, 1, "title keybinding is buffer-local")
assert_equal(prompt_title(nil, title_keymap.callback).default, "Read input", "rename prompt prefills current title")
assert_equal(vim.bo.modified, false, "cancelled title prompt leaves buffer unmodified")

prompt_title("  Load\n input  ", function() vim.cmd.NotebookCellTitle() end)
assert_equal(vim.bo.modified, true, "title-only edit marks buffer modified")
assert_equal(vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n")).cells[1].metadata["application/vnd.databricks.v1+cell"].title,
  "Read input", "title edits do not write before saving")
local edited_marks = vim.api.nvim_buf_get_extmarks(title_buf, notebook._test.display_namespace, 0, -1, { details = true })
local edited_border_text = {}
for _, mark in ipairs(edited_marks) do
  table.insert(edited_border_text, extmark_text(mark))
end
assert_match(table.concat(edited_border_text), "Code — Load input", "renamed title refreshes border immediately")
vim.cmd.write()
local title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].title, "Load input", "rename preserves Databricks title format")
assert_equal(title_saved.cells[1].metadata.tags[1], "keep", "title edit preserves unrelated metadata")
assert_equal(title_saved.cells[1].outputs[1].text[1], "old output\n", "title edit preserves outputs")
assert_equal(title_saved.cells[1].execution_count, 7, "title edit preserves execution count")
assert_equal(title_saved.cells[1].id, "code-1", "title edit preserves original cell identity")
assert_equal(table.concat(title_saved.cells[1].source), "print('old')", "title edit preserves editable source content")
prompt_title("   ")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].title, nil, "empty title removes Databricks title")

vim.api.nvim_win_set_cursor(0, { 5, 0 })
assert_equal(prompt_title("Overview").default, "", "untitled Markdown cell prompt starts empty")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[2].metadata.title, "Overview", "Markdown title is stored as generic metadata")
assert_equal(prompt_title("Introduction").default, "Overview", "generic title is prefilled for renaming")
vim.cmd.write()
prompt_title("")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[2].metadata.title, nil, "empty title removes generic title")
assert_equal(vim.islist(title_saved.cells[2].metadata), false, "cleared metadata remains a JSON object")

notebook.insert_raw_cell()
prompt_title("New unsaved raw cell")
notebook.insert_code_cell_above()
prompt_title("New unsaved code cell")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[3].metadata.title, "New unsaved code cell", "new code cell can be titled before first save")
assert_equal(title_saved.cells[4].metadata.title, "New unsaved raw cell", "new raw title follows its cell through insertion")
assert_equal(type(title_saved.cells[3].id), "string", "new titled cell retains valid notebook id")
assert_equal(type(title_saved.cells[4].id), "string", "new titled raw cell has valid notebook id")

local saved_input = vim.ui.input
local pending_title = nil
vim.ui.input = function(_, callback) pending_title = callback end
notebook.edit_cell_title()
vim.ui.input = saved_input
vim.api.nvim_win_set_cursor(0, { 2, 0 })
pending_title("Captured cell")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[3].metadata.title, "Captured cell", "prompt targets original cell after cursor moves")
assert_equal(title_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].title, nil, "cursor movement does not retitle another cell")

vim.ui.input = function(_, callback) pending_title = callback end
notebook.edit_cell_title()
vim.ui.input = saved_input
vim.api.nvim_buf_set_lines(0, 1, 2, false, { "print('changed while prompting')" })
pending_title("Stale title")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].title, nil, "stale prompt cannot change edited notebook")

title_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].title = "Hidden title"
title_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].showTitle = false
title_saved.cells[1].metadata.title = "Fallback title"
vim.fn.writefile({ vim.json.encode(title_saved) }, title_edit)
vim.cmd.edit({ bang = true })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
assert_equal(prompt_title("Visible title").default, "Hidden title", "hidden Databricks title is available for renaming")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[1].metadata["application/vnd.databricks.v1+cell"].showTitle, true, "edited Databricks title is shown")
prompt_title("")
vim.cmd.write()
title_saved = vim.json.decode(table.concat(vim.fn.readfile(title_edit), "\n"))
assert_equal(title_saved.cells[1].metadata.title, nil, "removing Databricks title also removes fallback title")

vim.ui.input = function(_, callback) pending_title = callback end
notebook.edit_cell_title()
vim.ui.input = saved_input
vim.cmd.write()
pending_title("Prompt before save")
assert_equal(vim.bo.modified, false, "saving invalidates a pending title prompt")

vim.bo.modifiable = false
assert_equal(prompt_title("Locked"), nil, "unmodifiable notebook does not open title prompt")
vim.bo.modifiable = true
vim.ui.input = function(_, callback) pending_title = callback end
notebook.edit_cell_title()
vim.ui.input = saved_input
vim.cmd.bwipeout()
pending_title("Closed notebook")
vim.cmd.edit(vim.fn.fnameescape(title_edit))
assert_equal(vim.bo.modified, false, "prompt from wiped buffer cannot change reopened notebook")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "print('no marker')" })
assert_equal(prompt_title("No marker"), nil, "title command rejects a missing cell marker")
vim.cmd.edit({ bang = true })

vim.cmd.enew()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
notebook.insert_code_cell()
assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1], "plain text", "insert command skips non-notebook buffers")
assert_equal(prompt_title("Invalid buffer"), nil, "title command skips non-notebook buffers")
vim.cmd.bwipeout({ bang = true })

missing = vim.fn.tempname() .. ".ipynb"
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(missing))
assert_equal(vim.bo.filetype, "python", "missing notebook opens as Python")
assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1], "# %%", "missing notebook opens as a new cell")
prompt_title("First cell")
vim.cmd.write()
local missing_saved = vim.json.decode(table.concat(vim.fn.readfile(missing), "\n"))
assert_equal(missing_saved.nbformat, 4, "missing notebook writes valid nbformat")
assert_equal(vim.islist(missing_saved.cells[1].metadata), false, "missing notebook writes cell metadata as object")
assert_equal(missing_saved.cells[1].metadata.title, "First cell", "first cell in new notebook can be titled before saving")

empty = vim.fn.tempname() .. ".ipynb"
vim.fn.writefile({}, empty)
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(empty))
assert_equal(vim.bo.filetype, "python", "empty notebook opens as Python")
assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1], "# %%", "empty notebook opens as a new cell")
vim.cmd.write()
local empty_saved = vim.json.decode(table.concat(vim.fn.readfile(empty), "\n"))
assert_equal(empty_saved.nbformat, 4, "empty notebook writes valid nbformat")
assert_equal(#empty_saved.cells, 1, "empty notebook writes one code cell")

private = vim.fn.tempname() .. ".ipynb"
vim.fn.writefile({ vim.json.encode(original) }, private)
vim.fn.setfperm(private, "rw-------")
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(private))
vim.api.nvim_buf_set_lines(0, 1, 2, false, { "print('private')" })
vim.cmd.write()
assert_equal(vim.fn.getfperm(private), "rw-------", "notebook write preserves file permissions")

symlink_target = vim.fn.tempname() .. ".ipynb"
symlink_link = vim.fn.tempname() .. ".ipynb"
vim.fn.writefile({ vim.json.encode(original) }, symlink_target)
vim.uv.fs_symlink(symlink_target, symlink_link)
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(symlink_link))
vim.api.nvim_buf_set_lines(0, 1, 2, false, { "print('symlink')" })
vim.cmd.write()
local symlink_saved = vim.json.decode(table.concat(vim.fn.readfile(symlink_target), "\n"))
assert_equal(vim.fn.getftype(symlink_link), "link", "notebook write preserves symlink")
assert_equal(table.concat(symlink_saved.cells[1].source), "print('symlink')", "notebook write updates symlink target")

malformed = vim.fn.tempname() .. ".ipynb"
vim.fn.writefile({ '{"cells":["not-a-cell"],"metadata":{},"nbformat":4,"nbformat_minor":5}' }, malformed)
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(malformed))
assert_equal(vim.bo.filetype, "json", "malformed notebook opens as raw JSON")
assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]:match("not%-a%-cell") ~= nil, true, "malformed notebook keeps raw contents")

invalid = vim.fn.tempname() .. ".ipynb"
vim.fn.writefile({ "{" }, invalid)
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(invalid))
vim.cmd.write()
assert_equal(table.concat(vim.fn.readfile(invalid), "\n"), "{", "invalid notebook is not overwritten")

vim.fn.delete(temp)
vim.fn.delete(invalid)
vim.fn.delete(alternate)
vim.fn.delete(saveas)
vim.fn.delete(missing)
vim.fn.delete(empty)
vim.fn.delete(private)
vim.fn.delete(symlink_link)
vim.fn.delete(symlink_target)
vim.fn.delete(malformed)
vim.fn.delete(insertion)
vim.fn.delete(titled)
vim.fn.delete(title_edit)
print("notebook-roundtrip-ok")
