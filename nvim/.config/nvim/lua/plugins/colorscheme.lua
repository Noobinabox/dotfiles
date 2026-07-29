return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      terminal_colors = true,
      on_highlights = function(hl, colors)
        hl.SpellBad = { underline = true, sp = colors.red }
        hl.SpellCap = { underline = true, sp = colors.yellow }
        hl.SpellLocal = { underline = true, sp = colors.cyan }
        hl.SpellRare = { underline = true, sp = colors.purple }
        hl.RenderMarkdownCheckboxImportant = { fg = colors.yellow, bold = true }
        hl.RenderMarkdownCheckboxWorking = { fg = colors.blue }
        hl.RenderMarkdownCheckboxDeferred = { fg = colors.comment, strikethrough = true }
        hl.RenderMarkdownCheckboxQuestion = { fg = colors.orange }
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },
}
