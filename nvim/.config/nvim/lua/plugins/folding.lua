local tree_filetypes = {
  bash = true,
  c = true,
  cmake = true,
  cpp = true,
  css = true,
  html = true,
  javascript = true,
  javascriptreact = true,
  json = true,
  lua = true,
  markdown = true,
  markdown_inline = true,
  toml = true,
  tsx = true,
  typescript = true,
  typescriptreact = true,
  vim = true,
  vimdoc = true,
  yaml = true,
}

local function diff_foldexpr()
  local line = vim.fn.getline(vim.v.lnum)

  if line:match("^diff %-%-git ") then
    return ">1"
  end

  if line:match("^@@ ") then
    return ">2"
  end

  local previous = vim.fn.getline(vim.v.lnum - 1)
  if previous:match("^diff %-%-git ") then
    return "1"
  end

  if previous:match("^@@ ") then
    return "2"
  end

  return "="
end

_G.UserDiffFoldExpr = diff_foldexpr

local function setup_diff_folds()
  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "v:lua.UserDiffFoldExpr()"
  vim.opt_local.foldlevel = 99
  vim.opt_local.foldenable = true
end

local function is_marker_fold_start(lnum)
  if vim.wo.foldmethod ~= "marker" then
    return false
  end

  local start_marker = vim.split(vim.wo.foldmarker, ",", { plain = true })[1]
  return start_marker ~= "" and vim.fn.getline(lnum):find(start_marker, 1, true) ~= nil
end

local function is_diff_fold_start(lnum)
  if vim.bo.filetype ~= "diff" then
    return false
  end

  local line = vim.fn.getline(lnum)
  return line:match("^diff %-%-git ") ~= nil or line:match("^@@ ") ~= nil
end

local function indent_width(line)
  local indent = line:match("^%s*") or ""
  return vim.fn.strdisplaywidth(indent)
end

local function is_markdown_fold_start(lnum)
  if vim.bo.filetype ~= "markdown" and vim.bo.filetype ~= "mdx" then
    return false
  end

  local line = vim.fn.getline(lnum)
  if line:match("^#+%s+") then
    return true
  end

  if not line:match("^%s*[-*+]%s+") and not line:match("^%s*%d+[.)]%s+") then
    return false
  end

  local line_indent = indent_width(line)
  for next_lnum = lnum + 1, vim.api.nvim_buf_line_count(0) do
    local next_line = vim.fn.getline(next_lnum)
    if next_line:match("%S") then
      return indent_width(next_line) > line_indent
    end
  end

  return false
end

local function fold_status_marker()
  if vim.v.virtnum ~= 0 then
    return " "
  end

  if vim.fn.foldclosed(vim.v.lnum) == vim.v.lnum then
    return ""
  end

  local level = vim.fn.foldlevel(vim.v.lnum)
  if level == 0 then
    return " "
  end

  if vim.bo.filetype == "markdown" or vim.bo.filetype == "mdx" then
    return is_markdown_fold_start(vim.v.lnum) and "" or " "
  end

  if is_marker_fold_start(vim.v.lnum) or is_diff_fold_start(vim.v.lnum) then
    return ""
  end

  local previous_level = vim.v.lnum > 1 and vim.fn.foldlevel(vim.v.lnum - 1) or 0
  if level > previous_level then
    return ""
  end

  return " "
end

local function status_line_number()
  if vim.v.virtnum ~= 0 then
    return ""
  end

  local number
  if vim.wo.number and vim.wo.relativenumber then
    number = vim.v.relnum == 0 and vim.v.lnum or vim.v.relnum
  elseif vim.wo.number then
    number = vim.v.lnum
  elseif vim.wo.relativenumber then
    number = vim.v.relnum
  else
    return ""
  end

  return tostring(number)
end

_G.UserFoldStatusMarker = fold_status_marker
_G.UserFoldStatusLineNumber = status_line_number

return {
  {
    "kevinhwang91/nvim-ufo",
    event = { "BufReadPost", "BufNewFile", "StdinReadPost" },
    dependencies = {
      "kevinhwang91/promise-async",
    },
    init = function()
      vim.opt.foldcolumn = "0"
      vim.opt.statuscolumn = "%s%{v:lua.UserFoldStatusLineNumber()}%{v:lua.UserFoldStatusMarker()} "
      vim.opt.fillchars:append({
        foldopen = "",
        foldclose = "",
        foldsep = " ",
      })
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99
      vim.opt.foldenable = true
    end,
    config = function()
      local ufo = require("ufo")

      ufo.setup({
        provider_selector = function(_, filetype, buftype)
          if buftype ~= "" or filetype == "diff" then
            return ""
          end

          if tree_filetypes[filetype] then
            return { "treesitter", "indent" }
          end

          return { "lsp", "indent" }
        end,
      })

      vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
      vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "diff",
        callback = setup_diff_folds,
      })

      if vim.bo.filetype == "diff" then
        setup_diff_folds()
      end
    end,
  },
}
