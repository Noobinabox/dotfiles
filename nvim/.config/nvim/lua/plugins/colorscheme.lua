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
      local generated = vim.fn.stdpath("config") .. "/../theme-pack/nvim/current.lua"
      if vim.fn.filereadable(generated) == 1 then
        local loaded, error_message = pcall(dofile, generated)
        if not loaded then
          vim.notify("Could not load generated dotfiles theme: " .. error_message, vim.log.levels.WARN)
        end
      else
        local fallback = pcall(vim.cmd.colorscheme, "tokyonight-night")
        if not fallback then
          vim.cmd.colorscheme("habamax")
        end
      end
    end,
  },
}
