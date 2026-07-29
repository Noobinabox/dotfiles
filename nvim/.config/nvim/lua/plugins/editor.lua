return {
  {
    "nvim-mini/mini.icons",
    version = "*",
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
    opts = {},
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      explorer = {
        replace_netrw = true,
      },
      picker = {
        ui_select = true,
        sources = {
          explorer = {},
        },
      },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      vim.ui.select = Snacks.picker.select
    end,
    keys = {
      {
        "<leader>e",
        function()
          Snacks.explorer()
        end,
        desc = "Toggle file explorer",
      },
      {
        "<leader>E",
        function()
          local file = vim.api.nvim_buf_get_name(0)
          local cwd = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()

          Snacks.explorer({ cwd = cwd })
        end,
        desc = "Explorer current file directory",
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-mini/mini.icons",
    },
    opts = {
      preset = "modern",
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer local keymaps",
      },
    },
  },
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    cmd = {
      "TodoQuickFix",
      "TodoLocList",
      "TodoTrouble",
      "TodoTelescope",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {},
    keys = {
      { "<leader>xt", "<cmd>TodoTrouble<CR>", desc = "Todo comments" },
      { "<leader>xT", "<cmd>TodoTrouble keywords=TODO,FIX,FIXME<CR>", desc = "Todo/Fix/Fixme comments" },
    },
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
    keys = {
      { "<C-h>", "<cmd><C-U>TmuxNavigateLeft<CR>", desc = "Navigate left" },
      { "<C-j>", "<cmd><C-U>TmuxNavigateDown<CR>", desc = "Navigate down" },
      { "<C-k>", "<cmd><C-U>TmuxNavigateUp<CR>", desc = "Navigate up" },
      { "<C-l>", "<cmd><C-U>TmuxNavigateRight<CR>", desc = "Navigate right" },
      { "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<CR>", desc = "Navigate previous" },
    },
  },
}
