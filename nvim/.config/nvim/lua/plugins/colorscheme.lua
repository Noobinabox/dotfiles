return {
  {
    dir = vim.fn.stdpath("config"),
    name = "dotfiles-generated-theme",
    lazy = false,
    priority = 1000,
    config = function()
      local candidates = {
        vim.fn.expand("~/.config/theme-pack/nvim/current.lua"),
        vim.fn.getcwd() .. "/tools/.config/theme-pack/nvim/current.lua",
      }

      for _, path in ipairs(candidates) do
        if vim.uv.fs_stat(path) then
          dofile(path)
          return
        end
      end

      vim.cmd.colorscheme("habamax")
    end,
  },
}
