return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-mini/mini.icons",
    },
    init = function()
      vim.g.lualine_laststatus = vim.o.laststatus
      vim.o.laststatus = 3
    end,
    opts = function()
      local function root_dir()
        local root = vim.fs.root(0, ".git")
        if not root then
          return ""
        end

        return vim.fn.fnamemodify(root, ":t")
      end

      local function lazy_updates()
        return require("lazy.status").updates()
      end

      return {
        options = {
          theme = "auto",
          globalstatus = true,
          disabled_filetypes = {
            statusline = { "dashboard", "lazy", "mason" },
          },
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch" },
          lualine_c = {
            { root_dir },
            {
              "diagnostics",
              symbols = {
                error = "E:",
                warn = "W:",
                info = "I:",
                hint = "H:",
              },
            },
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            { "filename", path = 1, symbols = { modified = " +", readonly = " RO", unnamed = "[No Name]" } },
          },
          lualine_x = {
            {
              lazy_updates,
              cond = require("lazy.status").has_updates,
            },
            { "diff", symbols = { added = "+", modified = "~", removed = "-" } },
          },
          lualine_y = {
            { "progress", separator = " ", padding = { left = 1, right = 0 } },
            { "location", padding = { left = 0, right = 1 } },
          },
          lualine_z = {
            function()
              return os.date("%H:%M")
            end,
          },
        },
        extensions = { "lazy" },
      }
    end,
  },
}
