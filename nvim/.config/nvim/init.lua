vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.markdown")
require("config.lazy")
require("config.sessions").setup()
require("notebook").setup()

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("config.keymaps")
  end,
})
