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
    name = "dotfiles-generated-theme",
    lazy = false,
    priority = 1001,
    config = function()
      local function apply_generated_theme(path)
        local ok, err = pcall(dofile, path)
        if ok and vim.g.colors_name then
          return true
        end

        local message = ok and ("Generated theme did not set a colorscheme: " .. path)
          or ("Failed to load generated theme " .. path .. ": " .. tostring(err))

        vim.schedule(function()
          vim.notify(message, vim.log.levels.WARN)
        end)

        return false
      end

      local candidates = {
        vim.fn.expand("~/.config/theme-pack/nvim/current.lua"),
        vim.fn.getcwd() .. "/tools/.config/theme-pack/nvim/current.lua",
      }

      for _, path in ipairs(candidates) do
        if vim.uv.fs_stat(path) and apply_generated_theme(path) then
          return
        end
      end

      local ok = pcall(vim.cmd.colorscheme, "tokyonight-night")
      if not ok then
        vim.cmd.colorscheme("habamax")
      end
    end,
  },
}
