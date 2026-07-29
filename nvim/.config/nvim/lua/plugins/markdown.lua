local obsidian_vault = vim.env.OBSIDIAN_VAULT or "~/vault"

local function configure_obsidian_presentation_keys()
  local slides = require("obsidian.slides")

  if slides._custom_keymaps_configured then
    return
  end

  local start_presentation = slides.start_presentation

  slides.start_presentation = function(note)
    start_presentation(note)

    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()

      if
        not vim.api.nvim_buf_is_valid(buf)
        or vim.bo[buf].buftype ~= "nofile"
        or vim.bo[buf].filetype ~= "markdown"
      then
        return
      end

      local function map(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, {
          buffer = buf,
          desc = desc,
          remap = true,
        })
      end

      map("<Space>", "n", "Next slide")
      map("<Right>", "n", "Next slide")
      map("<PageDown>", "n", "Next slide")
      map("l", "n", "Next slide")
      map("<Left>", "p", "Previous slide")
      map("<PageUp>", "p", "Previous slide")
      map("h", "p", "Previous slide")
      map("<Esc>", "q", "Close presentation")
    end)
  end

  slides._custom_keymaps_configured = true
end

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    opts = {
      file_types = { "markdown" },
      checkbox = {
        custom = {
          important = {
            raw = "[!]",
            rendered = "󰀪 ",
            highlight = "RenderMarkdownWarn",
            scope_highlight = "RenderMarkdownCheckboxImportant",
          },
          working = {
            raw = "[>]",
            rendered = "󰔟 ",
            highlight = "RenderMarkdownInfo",
            scope_highlight = "RenderMarkdownCheckboxWorking",
          },
          deferred = {
            raw = "[~]",
            rendered = "󰰱 ",
            highlight = "Comment",
            scope_highlight = "RenderMarkdownCheckboxDeferred",
          },
          question = {
            raw = "[?]",
            rendered = "󰘥 ",
            highlight = "RenderMarkdownWarn",
            scope_highlight = "RenderMarkdownCheckboxQuestion",
          },
        },
      },
      latex = {
        enabled = false,
      },
    },
  },
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    cmd = "Obsidian",
    dependencies = {
      "folke/snacks.nvim",
    },
    opts = {
      legacy_commands = false,
      workspaces = {
        {
          name = "notes",
          path = obsidian_vault,
        },
      },
      picker = {
        name = "snacks.picker",
        note_mappings = {
          insert_link = "<C-o>",
        },
      },
      note_id_func = function(title)
        return title
      end,
      note_path_func = function(spec)
        local path = spec.dir / (spec.title or spec.id)
        return path:with_suffix(".md")
      end,
      daily_notes = {
        folder = "Dailies",
        date_format = "%Y-%m-%d",
        template = "daily.md",
      },
      templates = {
        folder = "Templates",
      },
      checkbox = {
        enabled = false,
      },
      ui = {
        enable = false,
      },
    },
    config = function(_, opts)
      require("obsidian").setup(opts)
      configure_obsidian_presentation_keys()

      vim.api.nvim_create_autocmd("User", {
        pattern = "ObsidianNoteEnter",
        callback = function(ev)
          require("config.markdown").set_link_keymap(ev.buf)
        end,
      })
    end,
  },
}
