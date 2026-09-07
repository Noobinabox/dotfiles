local org_dir = vim.env.ORG_DIRECTORY or "~/org"
local org_roam_dir = vim.env.ORG_ROAM_DIRECTORY or (org_dir .. "/roam")
local org_callout_namespace = vim.api.nvim_create_namespace("dotfiles_org_callouts")
local org_display_namespace = vim.api.nvim_create_namespace("dotfiles_org_display")

local function normalize_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function path_has_prefix(path, prefix)
  return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

local function slugify(value)
  local slug = value:lower():gsub("[^a-z0-9]+", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  return slug ~= "" and slug or "untitled"
end

local callouts = {
  abstract = { rendered = "󰨸 Abstract", highlight = "RenderMarkdownInfo", body = "OrgCalloutInfoBody" },
  attention = { rendered = "󰀪 Attention", highlight = "RenderMarkdownWarn", body = "OrgCalloutWarnBody" },
  bug = { rendered = "󰨰 Bug", highlight = "RenderMarkdownError", body = "OrgCalloutErrorBody" },
  caution = { rendered = "󰳦 Caution", highlight = "RenderMarkdownError", body = "OrgCalloutErrorBody" },
  check = { rendered = "󰄬 Check", highlight = "RenderMarkdownSuccess", body = "OrgCalloutSuccessBody" },
  cite = { rendered = "󱆨 Cite", highlight = "RenderMarkdownQuote", body = "OrgCalloutQuoteBody" },
  danger = { rendered = "󱐌 Danger", highlight = "RenderMarkdownError", body = "OrgCalloutErrorBody" },
  done = { rendered = "󰄬 Done", highlight = "RenderMarkdownSuccess", body = "OrgCalloutSuccessBody" },
  error = { rendered = "󱐌 Error", highlight = "RenderMarkdownError", body = "OrgCalloutErrorBody" },
  example = { rendered = "󰉹 Example", highlight = "RenderMarkdownHint", body = "OrgCalloutHintBody" },
  fail = { rendered = "󰅖 Fail", highlight = "RenderMarkdownError", body = "OrgCalloutErrorBody" },
  failure = { rendered = "󰅖 Failure", highlight = "RenderMarkdownError", body = "OrgCalloutErrorBody" },
  faq = { rendered = "󰘥 Faq", highlight = "RenderMarkdownWarn", body = "OrgCalloutWarnBody" },
  help = { rendered = "󰘥 Help", highlight = "RenderMarkdownWarn", body = "OrgCalloutWarnBody" },
  hint = { rendered = "󰌶 Hint", highlight = "RenderMarkdownSuccess", body = "OrgCalloutSuccessBody" },
  important = { rendered = "󰅾 Important", highlight = "RenderMarkdownHint", body = "OrgCalloutHintBody" },
  info = { rendered = "󰋽 Info", highlight = "RenderMarkdownInfo", body = "OrgCalloutInfoBody" },
  missing = { rendered = "󰅖 Missing", highlight = "RenderMarkdownError", body = "OrgCalloutErrorBody" },
  note = { rendered = "󰋽 Note", highlight = "RenderMarkdownInfo", body = "OrgCalloutInfoBody" },
  question = { rendered = "󰘥 Question", highlight = "RenderMarkdownWarn", body = "OrgCalloutWarnBody" },
  quote = { rendered = "󱆨 Quote", highlight = "RenderMarkdownQuote", body = "OrgCalloutQuoteBody" },
  success = { rendered = "󰄬 Success", highlight = "RenderMarkdownSuccess", body = "OrgCalloutSuccessBody" },
  summary = { rendered = "󰨸 Summary", highlight = "RenderMarkdownInfo", body = "OrgCalloutInfoBody" },
  tip = { rendered = "󰌶 Tip", highlight = "RenderMarkdownSuccess", body = "OrgCalloutSuccessBody" },
  tldr = { rendered = "󰨸 Tldr", highlight = "RenderMarkdownInfo", body = "OrgCalloutInfoBody" },
  todo = { rendered = "󰗡 Todo", highlight = "RenderMarkdownInfo", body = "OrgCalloutInfoBody" },
  warning = { rendered = "󰀪 Warning", highlight = "RenderMarkdownWarn", body = "OrgCalloutWarnBody" },
}

local function callout_config(kind)
  return callouts[kind] or { rendered = kind:upper(), highlight = "RenderMarkdownQuote", body = "OrgCalloutQuoteBody" }
end

local function apply_org_highlights()
  local palette = {
    blue = "#7aa2f7",
    cyan = "#7dcfff",
    green = "#9ece6a",
    magenta = "#bb9af7",
    orange = "#ff9e64",
    red = "#f7768e",
    yellow = "#e0af68",
  }

  local highlights = {
    OrgLevel1 = { fg = palette.blue, bold = true },
    OrgLevel2 = { fg = palette.green, bold = true },
    OrgLevel3 = { fg = palette.magenta, bold = true },
    OrgLevel4 = { fg = palette.orange, bold = true },
    OrgLevel5 = { fg = palette.cyan, bold = true },
    OrgLevel6 = { fg = palette.yellow, bold = true },
    OrgLevel7 = { fg = palette.red, bold = true },
    OrgLevel8 = { fg = palette.blue, bold = true },
    OrgTODO = { fg = palette.red, bold = true },
    OrgDONE = { fg = palette.green, bold = true },
    OrgPriorityHigh = { fg = palette.red, bold = true },
    OrgPriorityMedium = { fg = palette.orange, bold = true },
    OrgPriorityLow = { fg = palette.yellow },
    OrgDate = { fg = palette.cyan },
    OrgLink = { fg = palette.blue, underline = true },
    OrgTag = { fg = palette.magenta },
    OrgCode = { fg = palette.green },
    OrgBlock = { fg = palette.cyan },
    OrgBlockBeginLine = { fg = palette.yellow },
    OrgBlockEndLine = { fg = palette.yellow },
    OrgListBullet1 = { fg = palette.blue, bold = true },
    OrgListBullet2 = { fg = palette.green, bold = true },
    OrgListBullet3 = { fg = palette.magenta, bold = true },
    OrgListBullet4 = { fg = palette.orange, bold = true },
    OrgListBullet5 = { fg = palette.cyan, bold = true },
    OrgListBullet6 = { fg = palette.yellow, bold = true },
    OrgListBullet7 = { fg = palette.red, bold = true },
    OrgListBullet8 = { fg = palette.blue, bold = true },
    OrgCalloutErrorBody = { bg = "#3b1d2b" },
    OrgCalloutHintBody = { bg = "#2d2640" },
    OrgCalloutInfoBody = { bg = "#1f2a44" },
    OrgCalloutQuoteBody = { bg = "#1f2335" },
    OrgCalloutSuccessBody = { bg = "#1f3327" },
    OrgCalloutWarnBody = { bg = "#332b1d" },
  }

  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end

  local fallback_highlights = {
    RenderMarkdownError = { fg = palette.red, bold = true },
    RenderMarkdownHint = { fg = palette.magenta, bold = true },
    RenderMarkdownInfo = { fg = palette.blue, bold = true },
    RenderMarkdownQuote = { fg = palette.cyan, bold = true },
    RenderMarkdownSuccess = { fg = palette.green, bold = true },
    RenderMarkdownWarn = { fg = palette.yellow, bold = true },
  }
  for group, opts in pairs(fallback_highlights) do
    if vim.fn.hlexists(group) == 0 then
      vim.api.nvim_set_hl(0, group, opts)
    end
  end
end

local function apply_org_callout_matches()
  if vim.b.dotfiles_org_callout_matches then
    return
  end

  vim.b.dotfiles_org_callout_matches = {
    vim.fn.matchadd("RenderMarkdownInfo", [[^#\+begin_callout\s\+\(note\|info\|todo\|abstract\|summary\|tldr\)\>.*$]], 9),
    vim.fn.matchadd("RenderMarkdownSuccess", [[^#\+begin_callout\s\+\(tip\|hint\|success\|check\|done\)\>.*$]], 9),
    vim.fn.matchadd("RenderMarkdownHint", [[^#\+begin_callout\s\+\(important\|example\)\>.*$]], 9),
    vim.fn.matchadd("RenderMarkdownWarn", [[^#\+begin_callout\s\+\(warning\|attention\|question\|faq\|help\)\>.*$]], 9),
    vim.fn.matchadd("RenderMarkdownError", [[^#\+begin_callout\s\+\(caution\|danger\|error\|fail\|failure\|missing\|bug\)\>.*$]], 9),
    vim.fn.matchadd("RenderMarkdownQuote", [[^#\+\(begin\|end\)_callout.*$]], 8),
  }
end

local function callout_body_group(kind)
  return callout_config(kind).body
end

local function callout_marker(kind, title)
  local config = callout_config(kind)
  return "▋ " .. config.rendered .. (title ~= "" and " " .. title or "")
end

local function render_org_callout_blocks(args)
  local bufnr = args.buf
  vim.api.nvim_buf_clear_namespace(bufnr, org_callout_namespace, 0, -1)

  local active_group = nil
  local active_marker_group = nil
  for index, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local kind, title = line:match("^#%+begin_callout%s+(%S+)%s*(.*)$")
    if kind then
      kind = kind:lower()
      local config = callout_config(kind)
      active_group = config.body
      active_marker_group = config.highlight
      vim.api.nvim_buf_set_extmark(bufnr, org_callout_namespace, index - 1, 0, {
        end_col = #line,
        line_hl_group = active_group,
        conceal = "",
        virt_text = { { callout_marker(kind, title), active_marker_group } },
        virt_text_pos = "inline",
      })
    elseif line:match("^#%+end_callout") then
      vim.api.nvim_buf_set_extmark(bufnr, org_callout_namespace, index - 1, 0, {
        end_col = #line,
        line_hl_group = active_group or "OrgCalloutQuoteBody",
        conceal = "",
      })
      active_group = nil
      active_marker_group = nil
    elseif active_group then
      vim.api.nvim_buf_set_extmark(bufnr, org_callout_namespace, index - 1, 0, {
        line_hl_group = active_group,
        virt_text = { { "▋ ", active_marker_group or "RenderMarkdownQuote" } },
        virt_text_pos = "inline",
      })
    end
  end
end

local function render_org_list_bullets(args)
  local bufnr = args.buf
  vim.api.nvim_buf_clear_namespace(bufnr, org_display_namespace, 0, -1)

  for index, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local _, bullet_end = line:find("^%s*%+%s")
    if bullet_end then
      local indent = (line:match("^(%s*)") or ""):gsub("\t", "  ")
      local level = math.floor(#indent / 2) % 8 + 1
      vim.api.nvim_buf_set_extmark(bufnr, org_display_namespace, index - 1, bullet_end - 2, {
        end_col = bullet_end - 1,
        conceal = "",
        hl_group = "OrgListBullet" .. level,
        priority = 200,
        virt_text = { { "➤ ", "OrgListBullet" .. level } },
        virt_text_pos = "inline",
      })
    end
  end
end

local function org_timestamp_for(value)
  if value and value:match("^%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d$") then
    return os.date("%Y-%m-%d %H:%M:%S")
  end
  if value and value:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return os.date("%Y-%m-%d")
  end
  if value and value:match("^%[%d%d%d%d%-%d%d%-%d%d%s+%a%a%a%s+%d%d:%d%d%]$") then
    return os.date("[%Y-%m-%d %a %H:%M]")
  end
  if value and value:match("^<%d%d%d%d%-%d%d%-%d%d%s+%a%a%a%s+%d%d:%d%d>$") then
    return os.date("<%Y-%m-%d %a %H:%M>")
  end
  return os.date("%Y-%m-%d %H:%M:%S")
end

local function update_org_file_updated_property(args)
  local bufnr = args.buf
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local scan_end = line_count
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line_count, false)

  for index, line in ipairs(lines) do
    if line:match("^%*+%s+") then
      scan_end = index - 1
      break
    end
  end

  local drawer_start = nil
  local drawer_end = nil
  for index = 1, scan_end do
    if lines[index]:match("^%s*:PROPERTIES:%s*$") then
      drawer_start = index
    elseif drawer_start and lines[index]:match("^%s*:END:%s*$") then
      drawer_end = index
      break
    end
  end

  if drawer_start and drawer_end then
    for index = drawer_start + 1, drawer_end - 1 do
      local value = lines[index]:match("^%s*:UPDATED:%s*(.-)%s*$")
      if value then
        lines[index] = ":UPDATED: " .. org_timestamp_for(value)
        vim.api.nvim_buf_set_lines(bufnr, 0, line_count, false, lines)
        return
      end
    end
    table.insert(lines, drawer_end, ":UPDATED: " .. org_timestamp_for(nil))
    vim.api.nvim_buf_set_lines(bufnr, 0, line_count, false, lines)
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
    ":PROPERTIES:",
    ":UPDATED: " .. org_timestamp_for(nil),
    ":END:",
  })
end

local function fold_org_property_drawers(args)
  local winid = vim.fn.bufwinid(args.buf)
  if winid == -1 then
    return
  end

  vim.api.nvim_win_call(winid, function()
    vim.cmd("silent! normal! zR")
    for row, line in ipairs(vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)) do
      if line:match("^%s*:PROPERTIES:%s*$") then
        vim.fn.cursor(row, 1)
        vim.cmd("silent! normal! zc")
      end
    end
    vim.fn.cursor(1, 1)
  end)
end

local function rename_org_roam_file_with_id(args)
  local filename = normalize_path(vim.api.nvim_buf_get_name(args.buf))
  local roam_root = normalize_path(org_roam_dir)
  if not path_has_prefix(filename, roam_root) or not filename:match("%.org$") then
    return
  end
  local daily_root = normalize_path(vim.fs.joinpath(org_roam_dir, "daily"))
  if path_has_prefix(filename, daily_root) then
    return
  end

  local basename = vim.fn.fnamemodify(filename, ":t")
  if basename:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x%-") then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(args.buf, 0, math.min(vim.api.nvim_buf_line_count(args.buf), 40), false)
  local id = nil
  local title = nil
  for _, line in ipairs(lines) do
    id = id or line:match("^:ID:%s+([0-9a-fA-F%-]+)%s*$")
    title = title or line:match("^#%+[Tt][Ii][Tt][Ll][Ee]:%s+(.+)%s*$")
  end
  if not id then
    return
  end

  local stem = vim.fn.fnamemodify(filename, ":t:r"):gsub("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%-", "")
  local new_name = id:lower() .. "-" .. slugify(title or stem) .. ".org"
  local new_path = vim.fs.joinpath(vim.fn.fnamemodify(filename, ":h"), new_name)
  if new_path == filename or vim.fn.filereadable(new_path) == 1 then
    return
  end

  vim.loop.fs_rename(filename, new_path)
  vim.api.nvim_buf_set_name(args.buf, new_path)
end

local function node_values(values)
  if type(values) ~= "table" then
    return {}
  end

  local result = {}
  for _, value in ipairs(values) do
    if type(value) == "string" and value ~= "" then
      table.insert(result, value)
    end
  end

  return result
end

local function org_roam_tag_chain_tokens(tags)
  local tokens = {}
  local normalized = {}
  local seen = {}

  for _, tag in ipairs(tags) do
    local value = tag:lower():gsub("^:+", ""):gsub(":+$", "")
    if value ~= "" and not seen[value] then
      seen[value] = true
      table.insert(normalized, value)
      table.insert(tokens, ":" .. value .. ":")
    end
  end

  local max_depth = math.min(#normalized, 6)
  local function visit(prefix, used, depth)
    if depth > 1 then
      table.insert(tokens, ":" .. table.concat(prefix, ":") .. ":")
    end
    if depth == max_depth then
      return
    end

    for index, tag in ipairs(normalized) do
      if not used[index] then
        used[index] = true
        table.insert(prefix, tag)
        visit(prefix, used, depth + 1)
        table.remove(prefix)
        used[index] = nil
      end
    end
  end

  visit({}, {}, 0)
  return tokens
end

local function org_roam_node_item_text(node)
  local parts = { node.title or "Untitled" }
  local aliases = node_values(node.aliases)
  local tags = node_values(node.tags)

  if #aliases > 0 then
    table.insert(parts, table.concat(aliases, " "))
  end

  if #tags > 0 then
    table.insert(parts, table.concat(tags, " "))
    vim.list_extend(parts, org_roam_tag_chain_tokens(tags))
  end

  if node.file then
    table.insert(parts, vim.fn.fnamemodify(node.file, ":~:."))
  end

  return table.concat(parts, " ")
end

local function org_roam_node_display(node)
  local display = node.title or "Untitled"
  local aliases = node_values(node.aliases)
  local tags = node_values(node.tags)

  if #aliases > 0 then
    display = display .. "  aliases: " .. table.concat(aliases, ", ")
  end

  if #tags > 0 then
    display = display .. "  :" .. table.concat(tags, ":") .. ":"
  end

  return display
end

local function org_roam_snacks_items(roam)
  local items = {}

  for _, id in ipairs(roam.database:ids()) do
    local node = roam.database:get_sync(id)
    if node and type(node.file) == "string" then
      local row = node.range and node.range.start and node.range.start.row
      local column = node.range and node.range.start and node.range.start.column
      table.insert(items, {
        text = org_roam_node_item_text(node),
        node = node,
        file = node.file,
        pos = type(row) == "number" and type(column) == "number" and { row + 1, column } or nil,
        display = org_roam_node_display(node),
        aliases = node_values(node.aliases),
        tags = node_values(node.tags),
      })
    end
  end

  return items
end

local function fuzzy_contains(value, query)
  value = value:lower()
  query = query:lower()

  local offset = 1
  for index = 1, #query do
    local char = query:sub(index, index)
    offset = value:find(char, offset, true)
    if not offset then
      return false
    end
    offset = offset + 1
  end

  return true
end

local function parse_tag_query(query)
  local tags = {}

  if not query:match("^:") then
    return tags
  end

  for tag in query:gmatch(":([^:]+)") do
    tag = vim.trim(tag):lower()
    if tag ~= "" then
      table.insert(tags, tag)
    end
  end

  return tags
end

local function item_has_tags(item, required_tags)
  local tags = {}
  for _, tag in ipairs(item.tags or {}) do
    tags[tag:lower()] = true
  end

  for _, tag in ipairs(required_tags) do
    if not tags[tag] then
      return false
    end
  end

  return true
end

local function item_title_matches(item, query)
  query = query:lower()
  if (item.node.title or ""):lower() == query then
    return true
  end
  for _, alias in ipairs(item.aliases or {}) do
    if alias:lower() == query then
      return true
    end
  end
  return false
end

local function filtered_org_roam_items(items, query)
  query = vim.trim(query or "")
  if query == "" then
    return vim.deepcopy(items), false
  end

  local required_tags = parse_tag_query(query)
  local tag_query = #required_tags > 0
  local filtered = {}
  local exact_match = false

  for _, item in ipairs(items) do
    local matches = tag_query and item_has_tags(item, required_tags) or fuzzy_contains(item.text, query)
    if matches then
      table.insert(filtered, item)
    end
    exact_match = exact_match or item_title_matches(item, query)
  end

  if not tag_query and not exact_match then
    table.insert(filtered, 1, {
      text = "Create " .. query,
      display = "Create node: " .. query,
      create_title = query,
    })
  end

  return filtered, tag_query
end

local function visual_selection_text()
  local mode = vim.fn.mode()
  if not mode:match("[vV]") then
    return nil
  end

  local ok, selection = pcall(function()
    local lines = require("org-roam").utils.get_visual_selection({ single_line = true })
    return lines[1]
  end)
  if ok then
    return selection
  end

  return nil
end

local function open_org_roam_node_item(item)
  if not item or not item.file then
    return
  end

  vim.cmd.edit({ item.file, bang = true })
  vim.cmd.filetype("detect")
  vim.schedule(function()
    if item.pos then
      pcall(vim.api.nvim_win_set_cursor, 0, item.pos)
    end
  end)
end

local function visit_org_roam_node(roam, id)
  local node = id and roam.database:get_sync(id)
  if not node then
    return
  end

  local row = node.range and node.range.start and node.range.start.row
  local column = node.range and node.range.start and node.range.start.column
  open_org_roam_node_item({
    file = node.file,
    pos = type(row) == "number" and type(column) == "number" and { row + 1, column } or nil,
  })
end

local function find_missing_org_roam_node(roam, title)
  if title and vim.trim(title) ~= "" then
    vim.schedule(function()
      if not roam.api.capture_node then
        vim.notify("Org-roam capture_node API is not available", vim.log.levels.ERROR)
        return
      end

      roam.api.capture_node({ title = title }):next(function(id)
        visit_org_roam_node(roam, id)
      end)
    end)
  end
end

local function picker_search_text(picker)
  if not picker or not picker.input or not picker.input.filter then
    return nil
  end

  return picker.input.filter.search ~= "" and picker.input.filter.search or picker.input.filter.pattern
end

local function find_org_roam_node_with_snacks(roam)
  if not _G.Snacks or not Snacks.picker then
    vim.notify("Snacks picker is not available", vim.log.levels.WARN)
    return
  end

  local ok, items = pcall(org_roam_snacks_items, roam)
  if not ok then
    vim.notify("Unable to load Org-roam nodes: " .. tostring(items), vim.log.levels.ERROR)
    return
  end
  if #items == 0 then
    roam.api.find_node({ title = visual_selection_text() })
    return
  end

  Snacks.picker.pick({
    source = "org_roam_nodes",
    title = "Org-roam nodes",
    live = true,
    finder = function(_, ctx)
      return filtered_org_roam_items(items, ctx.filter.search)
    end,
    actions = {
      create_node = function(picker)
        local title = picker_search_text(picker)
        picker:close()
        find_missing_org_roam_node(roam, title)
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-y>"] = { "create_node", mode = { "n", "i" }, desc = "Create Org-roam node" },
        },
      },
      list = {
        keys = {
          ["<c-y>"] = { "create_node", mode = "n", desc = "Create Org-roam node" },
        },
      },
    },
    format = function(item)
      return { { item.display or item.text } }
    end,
    preview = "file",
    pattern = visual_selection_text(),
    confirm = function(picker, item)
      if item and item.create_title then
        picker:close()
        find_missing_org_roam_node(roam, item.create_title)
      elseif item then
        picker:close()
        open_org_roam_node_item(item)
      else
        local title = picker_search_text(picker)
        picker:close()
        find_missing_org_roam_node(roam, title)
      end
    end,
  })
end

return {
  {
    "nvim-orgmode/orgmode",
    tag = "0.7.0",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      require("orgmode").setup({
        org_agenda_files = {
          org_dir .. "/inbox.org",
          org_dir .. "/projects.org",
          org_dir .. "/someday.org",
          org_dir .. "/tickler.org",
          org_roam_dir .. "/daily/*.org",
        },
        org_default_notes_file = org_dir .. "/inbox.org",
        org_archive_location = org_dir .. "/archive/%s_archive::",
        org_todo_keywords = {
          "TODO(t)",
          "NEXT(n)",
          "IMPORTANT(i)",
          "NEEDS_ATTENTION(a)",
          "CURRENTLY_WORKING(w)",
          "WAIT(W@/!)",
          "HOLD(h@/!)",
          "|",
          "DONE(d!)",
          "ABANDONED(A)",
          "CANCELLED(c@)",
        },
        org_todo_keyword_faces = {
          TODO = ":foreground #f7768e :weight bold",
          NEXT = ":foreground #7aa2f7 :weight bold",
          IMPORTANT = ":foreground #f7768e :weight bold",
          NEEDS_ATTENTION = ":foreground #e0af68 :weight bold",
          CURRENTLY_WORKING = ":foreground #7dcfff :weight bold",
          WAIT = ":foreground #e0af68 :weight bold",
          HOLD = ":foreground #ff9e64 :weight bold",
          DONE = ":foreground #9ece6a :weight bold",
          ABANDONED = ":foreground #565f89 :weight bold",
          CANCELLED = ":foreground #565f89 :weight bold",
        },
        org_log_done = "time",
        org_startup_folded = "showeverything",
        org_startup_indented = true,
        org_hide_leading_stars = true,
        org_hide_emphasis_markers = true,
        org_capture_templates = {
          t = {
            description = "Task",
            template = "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n",
            target = org_dir .. "/inbox.org",
            headline = "Inbox",
          },
          n = {
            description = "Note",
            template = "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n",
            target = org_dir .. "/notes.org",
            headline = "Inbox",
          },
          m = {
            description = "Meeting",
            template = "* %? :meeting:\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n",
            target = org_dir .. "/projects.org",
            headline = "Meetings",
          },
          T = {
            description = "Tickler",
            template = "* TODO %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n",
            target = org_dir .. "/tickler.org",
            headline = "Tickler",
          },
          j = {
            description = "Journal",
            template = "* %U\n%?",
            target = org_dir .. "/journal.org",
            datetree = true,
          },
        },
        mappings = {
          global = {
            org_agenda = "<leader>oa",
            org_capture = "<leader>oc",
          },
        },
      })

      apply_org_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("DotfilesOrgHighlights", { clear = true }),
        callback = apply_org_highlights,
      })
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("DotfilesOrgCallouts", { clear = true }),
        pattern = "org",
        callback = function(args)
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.breakindent = true
          vim.opt_local.breakindentopt = { "shift:2", "min:20" }
          vim.opt_local.showbreak = ""
          vim.opt_local.conceallevel = 2
          apply_org_callout_matches()
          render_org_callout_blocks(args)
          render_org_list_bullets(args)
          vim.schedule(function()
            fold_org_property_drawers(args)
          end)
        end,
      })
      vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
        group = vim.api.nvim_create_augroup("DotfilesOrgDisplayRender", { clear = true }),
        pattern = "*.org",
        callback = function(args)
          render_org_callout_blocks(args)
          render_org_list_bullets(args)
        end,
      })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("DotfilesOrgRoamFilenameIds", { clear = true }),
        pattern = "*.org",
        callback = rename_org_roam_file_with_id,
      })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("DotfilesOrgUpdatedProperty", { clear = true }),
        pattern = "*.org",
        callback = update_org_file_updated_property,
      })
      require("org_tasks").setup()
    end,
  },
  {
    "chipsenkbeil/org-roam.nvim",
    tag = "0.2.0",
    event = "VeryLazy",
    ft = { "org" },
    cmd = {
      "RoamAddAlias",
      "RoamAddOrigin",
      "RoamRemoveAlias",
      "RoamRemoveOrigin",
      "RoamReset",
      "RoamSave",
      "RoamUpdate",
    },
    dependencies = {
      "nvim-orgmode/orgmode",
    },
    config = function()
      require("org-roam").setup({
        directory = org_roam_dir,
        org_files = {
          org_dir .. "/*.org",
        },
        bindings = {
          prefix = "<leader>oz",
          find_node = false,
        },
        database = {
          update_on_save = true,
        },
        templates = {
          n = {
            description = "Note",
            template = "%?",
            target = "%<%Y%m%d%H%M%S>-%[slug].org",
          },
          d = {
            description = "Documentation",
            template = "#+filetags: :docs:\n\n%?",
            target = "docs/%<%Y%m%d%H%M%S>-%[slug].org",
          },
        },
        extensions = {
          dailies = {
            directory = "daily",
            templates = {
              d = {
                description = "Daily",
                template = "* %?",
                target = "%<%Y-%m-%d>.org",
              },
            },
          },
        },
      })
      vim.keymap.set({ "n", "v" }, "<leader>ozf", function()
        find_org_roam_node_with_snacks(require("org-roam"))
      end, { desc = "Org-roam find node" })
    end,
  },
}
