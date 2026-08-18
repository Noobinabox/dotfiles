return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
    },
  },
  {
    dir = vim.fn.stdpath("config"),
    name = "dotfiles-default-colorscheme",
    lazy = false,
    priority = 1001,
    config = function()
      local ok = pcall(vim.cmd.colorscheme, "tokyonight-night")
      if not ok then
        vim.cmd.colorscheme("habamax")
      end
    end,
  },
}
