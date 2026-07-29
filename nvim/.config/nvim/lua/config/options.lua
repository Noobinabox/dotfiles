local opt = vim.opt
local spelling = require("config.spelling")

spelling.setup()

vim.g.snacks_animate = false

opt.termguicolors = true
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.wrap = true
opt.linebreak = true
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 400
opt.splitright = true
opt.splitbelow = true
opt.completeopt = { "menu", "menuone", "noselect" }
opt.guicursor = {
  "n-v-c-sm:block",
  "i-ci-ve:ver35-blinkwait300-blinkon500-blinkoff300",
  "r-cr-o:hor20",
  "t:block",
}

opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.scrolloff = 8
opt.conceallevel = 1

opt.spell = true
opt.spelllang = "en_us"
opt.spellfile = spelling.spellfile
