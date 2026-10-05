local config_parent = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h"))
local active_theme_path = config_parent .. "/theme-pack/current-theme"
local active_theme = vim.fn.filereadable(active_theme_path) == 1
    and vim.fn.readfile(active_theme_path)[1]
  or ""

local native_themes = {
  ["tokyo-night"] = {
    repo = "folke/tokyonight.nvim",
    colorscheme = "tokyonight-night",
    opts = { style = "night" },
  },
  ["catppuccin-latte"] = {
    repo = "catppuccin/nvim",
    colorscheme = "catppuccin-latte",
    opts = { flavour = "latte" },
  },
  ["rose-pine-moon"] = {
    repo = "rose-pine/neovim",
    colorscheme = "rose-pine-moon",
  },
  ["gruvbox-light"] = {
    repo = "ellisonleao/gruvbox.nvim",
    colorscheme = "gruvbox",
    opts = { background = "light", contrast = "hard" },
  },
  ["github-light"] = {
    repo = "projekt0n/github-nvim-theme",
    colorscheme = "github_light",
  },
  ["solarized-light"] = {
    repo = "lifepillar/vim-solarized8",
    colorscheme = "solarized8",
  },
}

local selected_native = native_themes[active_theme]
local native_plugin = selected_native and {
  selected_native.repo,
  lazy = false,
  priority = 1000,
  opts = selected_native.opts,
} or nil

local generated_theme = config_parent .. "/theme-pack/nvim/current.lua"

local specs = {
  {
    dir = vim.fn.stdpath("config"),
    name = "dotfiles-default-colorscheme",
    lazy = false,
    priority = 1001,
    config = function()
      if selected_native then
        if active_theme == "solarized-light" then
          vim.o.background = "light"
        end
        local loaded, error_message = pcall(vim.cmd.colorscheme, selected_native.colorscheme)
        if not loaded then
          vim.notify("Could not load native theme: " .. error_message, vim.log.levels.WARN)
        end
      elseif vim.fn.filereadable(generated_theme) == 1 then
        local loaded, error_message = pcall(dofile, generated_theme)
        if not loaded then
          vim.notify("Could not load generated dotfiles theme: " .. error_message, vim.log.levels.WARN)
        end
      else
        vim.cmd.colorscheme("habamax")
      end
    end,
  },
}

if native_plugin then
  table.insert(specs, 1, native_plugin)
end

return specs
