return {
  {
    "dukjjang/codex-cli.nvim",
    cmd = {
      "CodexSend",
      "CodexAsk",
      "CodexToggle",
    },
    opts = {
      tmux = {
        command = "codex",
      },
      split = {
        command = "codex",
        direction = "right",
        size = 0.4,
      },
      overlay = {
        backdrop_blend = 95,
      },
      keymaps = {
        enabled = true,
        ask = "<leader>aa",
        visual = "<leader>aa",
        toggle = "<leader>at",
      },
      command = "CodexSend",
      command_ask = "CodexAsk",
      command_toggle = "CodexToggle",
    },
    config = function(_, opts)
      require("codex_cli").setup(opts)
      local overlay = require("codex_cli.overlay")
      local open = overlay.open

      overlay.open = function(...)
        open(...)
        vim.schedule(function()
          local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
          local normal_float = vim.api.nvim_get_hl(0, { name = "NormalFloat" })
          local bg = normal_float.bg or normal.bg

          vim.api.nvim_set_hl(0, "CodexCliBackdrop", { bg = "NONE" })
          vim.api.nvim_set_hl(0, "CodexCliPanel", { fg = normal.fg, bg = bg })

          for _, winid in ipairs(vim.api.nvim_list_wins()) do
            local winhl = vim.api.nvim_get_option_value("winhl", { win = winid })
            if winhl:find("CodexCliBackdrop", 1, true) then
              vim.api.nvim_set_option_value("winblend", 95, { win = winid })
            elseif winhl:find("CodexCli", 1, true) then
              vim.api.nvim_set_option_value("winblend", 0, { win = winid })
            end
          end
        end)
      end
    end,
    keys = {
      { "<leader>aa", "<cmd>CodexAsk<CR>", mode = { "n", "v" }, desc = "Codex ask with context" },
      { "<leader>at", "<cmd>CodexToggle<CR>", desc = "Codex toggle terminal" },
    },
  },
}
