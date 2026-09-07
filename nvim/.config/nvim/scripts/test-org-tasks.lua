local org_tasks = require("org_tasks")

local function set_buffer(lines, cursor_row)
  vim.cmd("enew!")
  vim.bo.filetype = "org"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_row or 1, 0 })
end

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function assert_lines(expected, label)
  local actual = lines()
  assert(vim.deep_equal(actual, expected), label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
end

set_buffer({
  "* TODO Parent [/]",
  "- [ ] one",
  "- [X] two",
  "- [ ] three",
}, 2)
org_tasks.toggle_checkbox()
assert_lines({
  "* TODO Parent [2/3]",
  "- [X] one",
  "- [X] two",
  "- [ ] three",
}, "checkbox count cookie")

set_buffer({
  "* TODO Parent [%]",
  "- [X] one",
  "- [ ] two",
  "- [ ] three",
}, 1)
org_tasks.update_statistics_at_point()
assert_lines({
  "* TODO Parent [33%]",
  "- [X] one",
  "- [ ] two",
  "- [ ] three",
}, "checkbox percent cookie")

set_buffer({
  "* TODO Parent [/]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo",
  ":END:",
  "** TODO one",
  "** DONE two",
  "- [X] checkbox ignored",
}, 1)
org_tasks.update_statistics_at_point()
assert_lines({
  "* TODO Parent [1/2]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo",
  ":END:",
  "** TODO one",
  "** DONE two",
  "- [X] checkbox ignored",
}, "todo cookie data")

set_buffer({
  "* TODO Parent [/]",
  ":PROPERTIES:",
  ":COOKIE_DATA: checkbox recursive",
  ":END:",
  "- [X] root checkbox",
  "** DONE child",
  "- [ ] nested checkbox",
}, 1)
org_tasks.update_statistics_at_point()
assert_lines({
  "* TODO Parent [1/1]",
  ":PROPERTIES:",
  ":COOKIE_DATA: checkbox recursive",
  ":END:",
  "- [X] root checkbox",
  "** DONE child",
  "- [ ] nested checkbox",
}, "checkbox cookie ignores child-heading checkboxes")

set_buffer({
  "* TODO Parent [/]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo recursive",
  ":END:",
  "** DONE one",
  "*** TODO two",
  "- [X] checkbox ignored",
}, 1)
org_tasks.update_statistics_at_point()
assert_lines({
  "* TODO Parent [1/2]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo recursive",
  ":END:",
  "** DONE one",
  "*** TODO two",
  "- [X] checkbox ignored",
}, "recursive todo cookie")

set_buffer({
  "#+TODO: OPEN(o) | CLOSED(c)",
  "* Parent [/]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo",
  ":END:",
  "** OPEN one",
  "** CLOSED two",
}, 2)
org_tasks.update_statistics_at_point()
assert_lines({
  "#+TODO: OPEN(o) | CLOSED(c)",
  "* Parent [1/2]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo",
  ":END:",
  "** OPEN one",
  "** CLOSED two",
}, "file-local todo keywords")

set_buffer({
  "* TODO Parent [/]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo",
  ":END:",
  "** TODO child",
}, 5)
local original_orgmode = package.loaded.orgmode
package.loaded.orgmode = {
  action = function(action)
    assert(action == "org_mappings.todo_next_state", "unexpected TODO action: " .. tostring(action))
    vim.api.nvim_buf_set_lines(0, 4, 5, false, { "** DONE child" })
  end,
}
org_tasks.todo("next")
package.loaded.orgmode = original_orgmode
assert_lines({
  "* TODO Parent [1/1]",
  ":PROPERTIES:",
  ":COOKIE_DATA: todo",
  ":END:",
  "** DONE child",
}, "todo wrapper updates parent cookie")

set_buffer({
  "* TODO Parent [/]",
  "- [-] group",
  "  - [X] one",
  "  - [ ] two",
}, 4)
org_tasks.toggle_checkbox()
assert_lines({
  "* TODO Parent [1/1]",
  "- [X] group",
  "  - [X] one",
  "  - [X] two",
}, "nested checkbox parent state")

set_buffer({
  "* TODO Ordered [/]",
  ":PROPERTIES:",
  ":ORDERED: t",
  ":END:",
  "- [ ] first",
  "- [ ] second",
}, 6)
local toggled = org_tasks.toggle_checkbox()
assert(toggled == false, "ordered checkbox should reject out-of-order completion")
assert_lines({
  "* TODO Ordered [/]",
  ":PROPERTIES:",
  ":ORDERED: t",
  ":END:",
  "- [ ] first",
  "- [ ] second",
}, "ordered checkbox rejection")

set_buffer({
  "* TODO Radio [/]",
  "#+ATTR_ORG: :radio t",
  "- [X] first",
  "- [ ] second",
}, 4)
org_tasks.toggle_checkbox()
assert_lines({
  "* TODO Radio [1/2]",
  "#+ATTR_ORG: :radio t",
  "- [ ] first",
  "- [X] second",
}, "radio checkbox siblings")

set_buffer({
  "* TODO Radio [/]",
  "#+ATTR_ORG: :radio t",
  "- [X] first",
  "- [ ] second",
  "- [ ] third",
}, 5)
org_tasks.toggle_checkbox()
assert_lines({
  "* TODO Radio [1/3]",
  "#+ATTR_ORG: :radio t",
  "- [ ] first",
  "- [ ] second",
  "- [X] third",
}, "radio checkbox third sibling")

set_buffer({
  "* TODO Separate Radio [/]",
  "#+ATTR_ORG: :radio t",
  "- [X] first",
  "",
  "- [ ] second",
}, 5)
org_tasks.toggle_checkbox()
assert_lines({
  "* TODO Separate Radio [2/2]",
  "#+ATTR_ORG: :radio t",
  "- [X] first",
  "",
  "- [X] second",
}, "radio checkbox stops at blank line")

set_buffer({
  "* TODO Separate Ordered [/]",
  ":PROPERTIES:",
  ":ORDERED: t",
  ":END:",
  "- [ ] first",
  "",
  "- [ ] second",
}, 7)
local separated_toggled = org_tasks.toggle_checkbox()
assert(separated_toggled == true, "ordered checkbox should not cross blank-line-separated lists")
assert_lines({
  "* TODO Separate Ordered [1/2]",
  ":PROPERTIES:",
  ":ORDERED: t",
  ":END:",
  "- [ ] first",
  "",
  "- [X] second",
}, "ordered checkbox stops at blank line")

set_buffer({
  "* TODO Markers [/]",
  "- one",
  "- [ ] two",
}, 2)
org_tasks.toggle_checkbox_marker(nil, 2, 3)
assert_lines({
  "* TODO Markers [0/1]",
  "- [ ] one",
  "- two",
}, "add and remove checkbox markers")

set_buffer({
  "* TODO Intermediate [/]",
  "- [ ] one",
}, 2)
org_tasks.force_intermediate_checkbox()
assert_lines({
  "* TODO Intermediate [0/1]",
  "- [-] one",
}, "force intermediate checkbox")

set_buffer({
  "* TODO Ordered",
  "- [ ] one",
}, 1)
org_tasks.toggle_ordered_property()
assert_lines({
  "* TODO Ordered",
  ":PROPERTIES:",
  ":ORDERED: t",
  ":END:",
  "- [ ] one",
}, "toggle ordered property on")
org_tasks.toggle_ordered_property()
assert_lines({
  "* TODO Ordered",
  ":PROPERTIES:",
  ":END:",
  "- [ ] one",
}, "toggle ordered property off")

set_buffer({
  "* TODO Radio",
  "- [ ] one",
  "- [ ] two",
}, 2)
org_tasks.toggle_radio_property()
assert_lines({
  "* TODO Radio",
  "#+ATTR_ORG: :radio t",
  "- [ ] one",
  "- [ ] two",
}, "toggle radio property on")
vim.api.nvim_win_set_cursor(0, { 3, 0 })
org_tasks.toggle_radio_property()
assert_lines({
  "* TODO Radio",
  "- [ ] one",
  "- [ ] two",
}, "toggle radio property off")

set_buffer({
  "* TODO Separate Radio",
  "- [ ] first",
  "",
  "- [ ] second",
}, 4)
org_tasks.toggle_radio_property()
assert_lines({
  "* TODO Separate Radio",
  "- [ ] first",
  "",
  "#+ATTR_ORG: :radio t",
  "- [ ] second",
}, "toggle radio property stops at blank line")

set_buffer({
  "* TODO First [/]",
  "- [ ] one",
  "* TODO Second",
  "Plain text",
}, 4)
local updated = org_tasks.update_statistics_at_point()
assert(updated == false, "unrelated previous cookie should not be updated")
assert_lines({
  "* TODO First [/]",
  "- [ ] one",
  "* TODO Second",
  "Plain text",
}, "no cross-heading cookie update")

set_buffer({
  "* TODO Parent [/]",
  "- [ ] one",
}, 1)
vim.api.nvim_exec_autocmds("FileType", { buffer = 0 })
for _, lhs in ipairs({
  "<leader>ou",
  "<leader>oU",
  "<leader>oXt",
  "<C-Space>",
  "<leader>oXa",
  "<leader>oXi",
  "<leader>oXr",
  "<leader>oXo",
  "cit",
  "ciT",
  "<C-c><C-c>",
  "<C-c>#",
}) do
  local mapping = vim.fn.maparg(lhs, "n", false, true)
  assert(mapping and mapping.desc and mapping.desc ~= "", lhs .. " is missing a normal-mode description")
end

for _, lhs in ipairs({ "<leader>oXa", "<leader>oXi" }) do
  local mapping = vim.fn.maparg(lhs, "x", false, true)
  assert(mapping and mapping.desc and mapping.desc ~= "", lhs .. " is missing a visual-mode description")
end

for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(bufnr) then
    vim.bo[bufnr].modified = false
  end
end
print("org-tasks-ok")
