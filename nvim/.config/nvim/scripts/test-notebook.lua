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

  error(message, 0)
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    fail(("%s: expected %s, got %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
  end
end

temp = vim.fn.tempname() .. ".ipynb"
local original = {
  cells = {
    {
      cell_type = "code",
      execution_count = 7,
      id = "code-1",
      metadata = { tags = { "keep" } },
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
vim.cmd.edit(vim.fn.fnameescape(temp))

local buf = vim.api.nvim_get_current_buf()
local rendered = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
assert_equal(vim.bo[buf].filetype, "python", "notebook buffer filetype")

if rendered[1] ~= "# %%" or rendered[2] ~= "print('old')" or rendered[4] ~= "# %% [markdown]" then
  fail("notebook did not render as percent-cell Python")
end

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

missing = vim.fn.tempname() .. ".ipynb"
vim.cmd.enew()
vim.cmd.edit(vim.fn.fnameescape(missing))
assert_equal(vim.bo.filetype, "python", "missing notebook opens as Python")
assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1], "# %%", "missing notebook opens as a new cell")
vim.cmd.write()
local missing_saved = vim.json.decode(table.concat(vim.fn.readfile(missing), "\n"))
assert_equal(missing_saved.nbformat, 4, "missing notebook writes valid nbformat")
assert_equal(vim.islist(missing_saved.cells[1].metadata), false, "missing notebook writes cell metadata as object")

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
print("notebook-roundtrip-ok")
