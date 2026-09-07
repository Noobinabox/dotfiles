local M = {}

local FALLBACK_TODO_STATES = {
  TODO = true,
  NEXT = true,
  WAIT = true,
  HOLD = true,
}

local FALLBACK_DONE_STATES = {
  DONE = true,
  CANCELLED = true,
}

local function clean_todo_keyword(keyword)
  return keyword and keyword:gsub("%(.+%)$", "") or nil
end

local function parse_todo_definition(line)
  local definition = line:match("^%s*#%+TODO:%s+(.+)%s*$") or line:match("^%s*#%+SEQ_TODO:%s+(.+)%s*$")
  if not definition then
    return nil
  end

  local states = {}
  local state_type = "TODO"
  for token in definition:gmatch("%S+") do
    if token == "|" then
      state_type = "DONE"
    else
      states[clean_todo_keyword(token)] = state_type
    end
  end

  return states
end

local function get_file_todo_state_type(lines, keyword)
  for _, line in ipairs(lines) do
    local states = parse_todo_definition(line)
    if states and states[keyword] then
      return states[keyword]
    end
  end

  return nil
end

local function get_todo_state_type(keyword, lines)
  local file_type = lines and get_file_todo_state_type(lines, keyword)
  if file_type then
    return file_type
  end

  local ok, config = pcall(require, "orgmode.config")
  if ok and config.get_todo_keywords then
    local todo_keywords = config:get_todo_keywords()
    local keyword_config = todo_keywords and todo_keywords:keys()[keyword]
    if keyword_config then
      return keyword_config.type
    end
  end

  if FALLBACK_TODO_STATES[keyword] then
    return "TODO"
  end
  if FALLBACK_DONE_STATES[keyword] then
    return "DONE"
  end

  return nil
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Org tasks" })
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
end

local function parse_headline(line)
  local stars, text = line:match("^(%*+)%s+(.*)$")
  if not stars then
    return nil
  end

  return {
    level = #stars,
    text = text,
  }
end

local function find_property(lines, heading_row, property)
  local in_drawer = false
  for index = heading_row + 1, #lines do
    local line = lines[index]
    if parse_headline(line) then
      return nil
    end

    if line:match("^%s*:PROPERTIES:%s*$") then
      in_drawer = true
    elseif in_drawer and line:match("^%s*:END:%s*$") then
      return nil
    elseif in_drawer then
      local value = line:match("^%s*:" .. property .. ":%s+(.+)%s*$")
      if value then
        return value, index
      end
    end
  end

  return nil
end

local function parse_todo_keyword(line, lines)
  local headline = parse_headline(line)
  if not headline then
    return nil
  end

  local keyword = headline.text:match("^(%S+)")
  if get_todo_state_type(keyword, lines) then
    return keyword
  end

  return nil
end

local function parse_checkbox(line)
  local prefix, state, rest = line:match("^(%s*[-+*]%s*)%[([ Xx%-])%](.*)$")
  if not prefix then
    return nil
  end

  local indent = #(prefix:match("^(%s*)") or "")

  return {
    indent = indent,
    prefix = prefix,
    state = state == "x" and "X" or state,
    rest = rest,
  }
end

local function parse_list_item(line)
  local prefix, rest = line:match("^(%s*[-+*]%s+)(.*)$")
  if not prefix then
    return nil
  end

  return {
    indent = #(prefix:match("^(%s*)") or ""),
    prefix = prefix,
    rest = rest,
  }
end

local function find_cookie(line)
  local matches = {
    { kind = "count", start_col = line:find("%[%d*/%d*%]") },
    { kind = "count", start_col = line:find("%[/%]") },
    { kind = "percent", start_col = line:find("%[%d+%%%]") },
    { kind = "percent", start_col = line:find("%[%%%]") },
  }

  local best = nil
  for _, candidate in ipairs(matches) do
    if candidate.start_col and (not best or candidate.start_col < best.start_col) then
      local _, finish_col = line:find(candidate.kind == "count" and "%[%d*/%d*%]" or "%[%d+%%%]", candidate.start_col)
      if not finish_col then
        _, finish_col = line:find(candidate.kind == "count" and "%[/%]" or "%[%%%]", candidate.start_col)
      end
      best = {
        kind = candidate.kind,
        start_col = candidate.start_col,
        finish_col = finish_col,
      }
    end
  end

  return best
end

local function format_cookie(kind, complete, total)
  if kind == "percent" then
    local percent = total == 0 and 0 or math.floor((complete / total) * 100)
    return string.format("[%d%%]", percent)
  end

  return string.format("[%d/%d]", complete, total)
end

local function replace_cookie(line, cookie, complete, total)
  return line:sub(1, cookie.start_col - 1)
    .. format_cookie(cookie.kind, complete, total)
    .. line:sub(cookie.finish_col + 1)
end

local function heading_end(lines, row, level)
  for index = row + 1, #lines do
    local heading = parse_headline(lines[index])
    if heading and heading.level <= level then
      return index - 1
    end
  end

  return #lines
end

local function list_item_end(lines, row, indent)
  for index = row + 1, #lines do
    local checkbox = parse_checkbox(lines[index])
    local list_item = checkbox or parse_list_item(lines[index])
    local heading = parse_headline(lines[index])

    if heading then
      return index - 1
    end

    if list_item and list_item.indent <= indent then
      return index - 1
    end
  end

  return #lines
end

local function find_heading_row(lines, row)
  for index = row, 1, -1 do
    if parse_headline(lines[index]) then
      return index
    end
  end

  return nil
end

local function find_list_row(lines, row)
  for index = row, 1, -1 do
    local checkbox = parse_checkbox(lines[index])
    local list_item = checkbox or parse_list_item(lines[index])
    if list_item then
      if index == row then
        return index
      end

      local end_row = list_item_end(lines, index, list_item.indent)
      if row <= end_row then
        return index
      end
    end

    if parse_headline(lines[index]) then
      return nil
    end
  end

  return nil
end

local function get_cookie_data(lines, heading_row)
  local value = find_property(lines, heading_row, "COOKIE_DATA")
  if not value then
    return {}
  end

  local data = {}
  for token in value:gmatch("%S+") do
    data[token:lower()] = true
  end
  return data
end

local function count_checkboxes(lines, start_row, end_row, recursive, parent_indent)
  local complete = 0
  local total = 0
  local direct_indent = nil

  for index = start_row, end_row do
    local checkbox = parse_checkbox(lines[index])
    if checkbox and checkbox.indent > (parent_indent or -1) then
      if recursive then
        total = total + 1
        complete = complete + (checkbox.state == "X" and 1 or 0)
      else
        direct_indent = direct_indent or checkbox.indent
        if checkbox.indent == direct_indent then
          total = total + 1
          complete = complete + (checkbox.state == "X" and 1 or 0)
        end
      end
    end
  end

  return complete, total
end

local function count_heading_checkboxes(lines, heading_row, recursive)
  local heading = parse_headline(lines[heading_row])
  local end_row = heading_end(lines, heading_row, heading.level)
  local complete = 0
  local total = 0
  local direct_indent = nil
  local index = heading_row + 1

  while index <= end_row do
    local child = parse_headline(lines[index])
    if child and child.level > heading.level and not recursive then
      index = heading_end(lines, index, child.level) + 1
    else
      local checkbox = parse_checkbox(lines[index])
      if checkbox then
        if recursive then
          total = total + 1
          complete = complete + (checkbox.state == "X" and 1 or 0)
        else
          direct_indent = direct_indent or checkbox.indent
          if checkbox.indent == direct_indent then
            total = total + 1
            complete = complete + (checkbox.state == "X" and 1 or 0)
          end
        end
      end
      index = index + 1
    end
  end

  return complete, total
end

local function count_heading_todos(lines, heading_row, recursive)
  local heading = parse_headline(lines[heading_row])
  local end_row = heading_end(lines, heading_row, heading.level)
  local complete = 0
  local total = 0

  for index = heading_row + 1, end_row do
    local child = parse_headline(lines[index])
    if child and child.level > heading.level and (recursive or child.level == heading.level + 1) then
      local keyword = parse_todo_keyword(lines[index], lines)
      if keyword then
        total = total + 1
        complete = complete + (get_todo_state_type(keyword, lines) == "DONE" and 1 or 0)
      end
    end
  end

  return complete, total
end

local function choose_heading_source(lines, heading_row, changed_kind)
  local cookie_data = get_cookie_data(lines, heading_row)
  if cookie_data.todo then
    return "todo", cookie_data.recursive
  end
  if cookie_data.checkbox then
    return "checkbox", false
  end
  if changed_kind then
    return changed_kind, false
  end

  local checkbox_complete, checkbox_total = count_heading_checkboxes(lines, heading_row, false)
  if checkbox_total > 0 then
    return "checkbox", false
  end

  local todo_complete, todo_total = count_heading_todos(lines, heading_row, false)
  if todo_total > 0 then
    return "todo", false
  end

  return checkbox_complete > 0 and "checkbox" or "todo", false
end

local function find_statistics_owner(lines, row)
  if find_cookie(lines[row] or "") then
    return row
  end

  local list_row = find_list_row(lines, row)
  if list_row and find_cookie(lines[list_row]) then
    return list_row
  end

  local heading_row = find_heading_row(lines, row)
  if heading_row and find_cookie(lines[heading_row]) then
    return heading_row
  end

  return nil
end

local function update_cookie_at(lines, row, changed_kind)
  local cookie = find_cookie(lines[row] or "")
  if not cookie then
    return false
  end

  local checkbox = parse_checkbox(lines[row])
  if checkbox then
    local complete, total = count_checkboxes(lines, row + 1, list_item_end(lines, row, checkbox.indent), false, checkbox.indent)
    lines[row] = replace_cookie(lines[row], cookie, complete, total)
    return true
  end

  local heading = parse_headline(lines[row])
  if heading then
    local source, recursive = choose_heading_source(lines, row, changed_kind)
    local complete, total
    if source == "todo" then
      complete, total = count_heading_todos(lines, row, recursive)
    else
      complete, total = count_heading_checkboxes(lines, row, recursive)
    end
    lines[row] = replace_cookie(lines[row], cookie, complete, total)
    return true
  end

  return false
end

local function same_list_sibling_rows(lines, row)
  local checkbox = parse_checkbox(lines[row])
  if not checkbox then
    return {}
  end

  local rows = {}
  local start_row = row
  for index = row - 1, 1, -1 do
    local sibling = parse_checkbox(lines[index])
    local item = sibling or parse_list_item(lines[index])
    if lines[index]:match("^%s*$") or parse_headline(lines[index]) or (item and item.indent < checkbox.indent) then
      break
    end
    if sibling and sibling.indent == checkbox.indent then
      start_row = index
    end
  end

  for index = start_row, #lines do
    local sibling = parse_checkbox(lines[index])
    local item = sibling or parse_list_item(lines[index])
    if
      index > row
      and (lines[index]:match("^%s*$") or parse_headline(lines[index]) or (item and item.indent < checkbox.indent))
    then
      break
    end
    if sibling and sibling.indent == checkbox.indent then
      table.insert(rows, index)
    end
  end

  return rows
end

local function heading_has_ordered_property(lines, row)
  local heading_row = find_heading_row(lines, row)
  if not heading_row then
    return false
  end

  return find_property(lines, heading_row, "ORDERED") == "t"
end

local function has_radio_attribute(lines, row)
  local checkbox = parse_checkbox(lines[row])
  if not checkbox then
    return false
  end

  for index = row - 1, 1, -1 do
    if lines[index]:match("^%s*$") then
      return false
    end

    if parse_headline(lines[index]) then
      return false
    end

      local item = parse_checkbox(lines[index]) or parse_list_item(lines[index])
      if item and item.indent < checkbox.indent then
        return false
      end

      if lines[index]:match("^%s*#%+ATTR_ORG:%s+:radio%s+t%s*$") then
        return true
      end
  end

  return false
end

local function set_checkbox_state(line, state)
  return line:gsub("^(%s*[-+*]%s*)%[[ Xx%-]%]", "%1[" .. state .. "]", 1)
end

local function sync_parent_list_states(lines, row)
  local current = parse_checkbox(lines[row])
  if not current then
    return
  end

  local current_indent = current.indent
  for index = row - 1, 1, -1 do
    local parent = parse_checkbox(lines[index])
    if parse_headline(lines[index]) then
      return
    end

    if parent and parent.indent < current_indent then
      local complete, total = count_checkboxes(lines, index + 1, list_item_end(lines, index, parent.indent), false, parent.indent)
      if total > 0 and complete == 0 then
        lines[index] = set_checkbox_state(lines[index], " ")
      elseif total > 0 and complete == total then
        lines[index] = set_checkbox_state(lines[index], "X")
      elseif total > 0 then
        lines[index] = set_checkbox_state(lines[index], "-")
      end
      current_indent = parent.indent
    end
  end
end

local function update_related_cookies(lines, row, changed_kind)
  local list_row = find_list_row(lines, row)
  while list_row do
    update_cookie_at(lines, list_row, "checkbox")
    local parent_indent = (parse_checkbox(lines[list_row]) or parse_list_item(lines[list_row])).indent
    local parent_row = nil
    for index = list_row - 1, 1, -1 do
      local item = parse_checkbox(lines[index]) or parse_list_item(lines[index])
      if parse_headline(lines[index]) then
        break
      end
      if item and item.indent < parent_indent then
        parent_row = index
        break
      end
    end
    list_row = parent_row
  end

  local heading_row = find_heading_row(lines, row)
  while heading_row do
    update_cookie_at(lines, heading_row, changed_kind)
    local heading = parse_headline(lines[heading_row])
    heading_row = heading and find_heading_row(lines, heading_row - 1) or nil
  end
end

local function write_lines(bufnr, lines)
  bufnr = bufnr or 0
  local current = get_lines(bufnr)
  local min_length = math.min(#current, #lines)
  local first_changed = 1

  while first_changed <= min_length and current[first_changed] == lines[first_changed] do
    first_changed = first_changed + 1
  end

  if first_changed > min_length and #current == #lines then
    return
  end

  local suffix_count = 0
  while
    suffix_count < min_length - first_changed + 1
    and current[#current - suffix_count] == lines[#lines - suffix_count]
  do
    suffix_count = suffix_count + 1
  end

  local replacement = {}
  for index = first_changed, #lines - suffix_count do
    table.insert(replacement, lines[index])
  end

  vim.api.nvim_buf_set_lines(bufnr, first_changed - 1, #current - suffix_count, false, replacement)
end

function M.update_statistics_at_point(bufnr, changed_kind)
  bufnr = bufnr or 0
  local lines = get_lines(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local owner = find_statistics_owner(lines, row)

  if not owner then
    notify("No Org statistics cookie found near cursor", vim.log.levels.WARN)
    return false
  end

  local updated = update_cookie_at(lines, owner, changed_kind)
  if updated then
    write_lines(bufnr, lines)
  end
  return updated
end

function M.update_all_statistics(bufnr)
  bufnr = bufnr or 0
  local lines = get_lines(bufnr)

  for row = #lines, 1, -1 do
    update_cookie_at(lines, row, nil)
  end

  write_lines(bufnr, lines)
end

function M.toggle_checkbox(bufnr)
  bufnr = bufnr or 0
  local lines = get_lines(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local checkbox = parse_checkbox(lines[row] or "")

  if not checkbox then
    notify("Cursor is not on an Org checkbox", vim.log.levels.WARN)
    return false
  end

  local next_state = checkbox.state == "X" and " " or "X"
  if next_state == "X" and heading_has_ordered_property(lines, row) then
    for _, sibling_row in ipairs(same_list_sibling_rows(lines, row)) do
      if sibling_row == row then
        break
      end
      local sibling = parse_checkbox(lines[sibling_row])
      if sibling and sibling.state ~= "X" then
        notify("Previous checkbox must be complete because this list is ordered", vim.log.levels.WARN)
        return false
      end
    end
  end

  if next_state == "X" and has_radio_attribute(lines, row) then
    for _, sibling_row in ipairs(same_list_sibling_rows(lines, row)) do
      if sibling_row ~= row then
        lines[sibling_row] = set_checkbox_state(lines[sibling_row], " ")
      end
    end
  end

  lines[row] = set_checkbox_state(lines[row], next_state)
  sync_parent_list_states(lines, row)
  update_related_cookies(lines, row, "checkbox")
  write_lines(bufnr, lines)
  return true
end

function M.toggle_checkbox_marker(bufnr, start_row, end_row)
  bufnr = bufnr or 0
  local lines = get_lines(bufnr)
  start_row = start_row or vim.api.nvim_win_get_cursor(0)[1]
  end_row = end_row or start_row

  for row = start_row, end_row do
    local checkbox = parse_checkbox(lines[row] or "")
    local item = parse_list_item(lines[row] or "")
    if checkbox then
      lines[row] = checkbox.prefix .. checkbox.rest:gsub("^%s*", "", 1)
    elseif item then
      lines[row] = item.prefix .. "[ ] " .. item.rest
    end
  end

  update_related_cookies(lines, end_row, "checkbox")
  write_lines(bufnr, lines)
end

function M.force_intermediate_checkbox(bufnr, start_row, end_row)
  bufnr = bufnr or 0
  local lines = get_lines(bufnr)
  start_row = start_row or vim.api.nvim_win_get_cursor(0)[1]
  end_row = end_row or start_row

  for row = start_row, end_row do
    if parse_checkbox(lines[row] or "") then
      lines[row] = set_checkbox_state(lines[row], "-")
      sync_parent_list_states(lines, row)
    end
  end

  update_related_cookies(lines, end_row, "checkbox")
  write_lines(bufnr, lines)
end

function M.toggle_ordered_property(bufnr)
  bufnr = bufnr or 0
  local lines = get_lines(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local heading_row = find_heading_row(lines, row)

  if not heading_row then
    notify("No Org heading found near cursor", vim.log.levels.WARN)
    return false
  end

  for index = heading_row + 1, #lines do
    if parse_headline(lines[index]) then
      break
    end
    if lines[index]:match("^%s*:ORDERED:%s+t%s*$") then
      table.remove(lines, index)
      write_lines(bufnr, lines)
      return true
    end
    if lines[index]:match("^%s*:END:%s*$") then
      table.insert(lines, index, ":ORDERED: t")
      write_lines(bufnr, lines)
      return true
    end
  end

  table.insert(lines, heading_row + 1, ":PROPERTIES:")
  table.insert(lines, heading_row + 2, ":ORDERED: t")
  table.insert(lines, heading_row + 3, ":END:")
  write_lines(bufnr, lines)
  return true
end

function M.toggle_radio_property(bufnr)
  bufnr = bufnr or 0
  local lines = get_lines(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local checkbox = parse_checkbox(lines[row] or "")

  if not checkbox then
    notify("Cursor is not on an Org checkbox", vim.log.levels.WARN)
    return false
  end

  local first_row = row
  for index = row - 1, 1, -1 do
    local sibling = parse_checkbox(lines[index])
    local item = sibling or parse_list_item(lines[index])
    if lines[index]:match("^%s*$") or parse_headline(lines[index]) or (item and item.indent < checkbox.indent) then
      break
    end
    if sibling and sibling.indent == checkbox.indent then
      first_row = index
    end
  end

  if lines[first_row - 1] and lines[first_row - 1]:match("^%s*#%+ATTR_ORG:%s+:radio%s+t%s*$") then
    table.remove(lines, first_row - 1)
  else
    table.insert(lines, first_row, "#+ATTR_ORG: :radio t")
  end

  write_lines(bufnr, lines)
  return true
end

function M.context_action()
  local lines = get_lines(0)
  local row = vim.api.nvim_win_get_cursor(0)[1]

  if parse_checkbox(lines[row] or "") then
    return M.toggle_checkbox()
  end

  if find_statistics_owner(lines, row) then
    return M.update_statistics_at_point()
  end

  local ok, orgmode = pcall(require, "orgmode")
  if ok then
    orgmode.action("org_mappings.open_at_point")
    return true
  end

  return false
end

function M.todo(direction)
  local ok, orgmode = pcall(require, "orgmode")
  if not ok then
    notify("orgmode is not available", vim.log.levels.WARN)
    return false
  end

  local before_row = vim.api.nvim_win_get_cursor(0)[1]
  orgmode.action(direction == "previous" and "org_mappings.todo_prev_state" or "org_mappings.todo_next_state")
  local row = math.min(vim.api.nvim_win_get_cursor(0)[1], before_row)
  local lines = get_lines(0)
  update_related_cookies(lines, row, "todo")
  write_lines(0, lines)
  return true
end

local function visual_range()
  local start_row = vim.fn.line("'<")
  local end_row = vim.fn.line("'>")
  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end
  return start_row, end_row
end

function M.setup()
  local group = vim.api.nvim_create_augroup("DotfilesOrgTasks", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "org",
    callback = function(args)
      local opts = function(desc)
        return { buffer = args.buf, silent = true, desc = desc }
      end

      vim.keymap.set("n", "<leader>ou", function()
        M.update_statistics_at_point(args.buf)
      end, opts("Org update statistics cookie"))
      vim.keymap.set("n", "<leader>oU", function()
        M.update_all_statistics(args.buf)
      end, opts("Org update all statistics cookies"))
      vim.keymap.set("n", "<leader>oXt", function()
        M.toggle_checkbox(args.buf)
      end, opts("Org toggle checkbox"))
      vim.keymap.set("n", "<C-Space>", function()
        M.toggle_checkbox(args.buf)
      end, opts("Org toggle checkbox"))
      vim.keymap.set("n", "<leader>oXa", function()
        M.toggle_checkbox_marker(args.buf)
      end, opts("Org add/remove checkbox marker"))
      vim.keymap.set("x", "<leader>oXa", function()
        local start_row, end_row = visual_range()
        M.toggle_checkbox_marker(args.buf, start_row, end_row)
      end, opts("Org add/remove checkbox markers"))
      vim.keymap.set("n", "<leader>oXi", function()
        M.force_intermediate_checkbox(args.buf)
      end, opts("Org force intermediate checkbox"))
      vim.keymap.set("x", "<leader>oXi", function()
        local start_row, end_row = visual_range()
        M.force_intermediate_checkbox(args.buf, start_row, end_row)
      end, opts("Org force intermediate checkboxes"))
      vim.keymap.set("n", "<leader>oXr", function()
        M.toggle_radio_property(args.buf)
      end, opts("Org toggle radio checkbox list"))
      vim.keymap.set("n", "<leader>oXo", function()
        M.toggle_ordered_property(args.buf)
      end, opts("Org toggle ordered checkbox property"))
      vim.keymap.set("n", "cit", function()
        M.todo("next")
      end, opts("Org TODO state"))
      vim.keymap.set("n", "ciT", function()
        M.todo("previous")
      end, opts("Org TODO state previous"))
      vim.keymap.set("n", "<C-c><C-c>", M.context_action, opts("Org context action"))
      vim.keymap.set("n", "<C-c>#", function()
        M.update_statistics_at_point(args.buf)
      end, opts("Org update statistics cookie"))
    end,
  })
end

return M
