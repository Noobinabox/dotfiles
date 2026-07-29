return {
  {
    "github/copilot.vim",
    cmd = "Copilot",
    event = "InsertEnter",
    init = function()
      vim.g.copilot_no_tab_map = true
    end,
    config = function()
      vim.keymap.set("i", "<C-l>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        desc = "Accept Copilot suggestion",
      })
      vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)", { remap = true, desc = "Next Copilot suggestion" })
      vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)", { remap = true, desc = "Previous Copilot suggestion" })
      vim.keymap.set("i", "<M-\\>", "<Plug>(copilot-suggest)", { remap = true, desc = "Request Copilot suggestion" })
      vim.keymap.set("i", "<C-]>", "<Plug>(copilot-dismiss)", { remap = true, desc = "Dismiss Copilot suggestion" })
    end,
  },
}
