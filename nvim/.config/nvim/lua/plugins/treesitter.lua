local parsers = {
  "bash",
  "c",
  "cmake",
  "cpp",
  "css",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "query",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = function()
      local treesitter = require("nvim-treesitter")
      treesitter.install(parsers, { max_jobs = 4 }):wait(300000)
      treesitter.update(parsers, { max_jobs = 4 }):wait(300000)
    end,
    lazy = false,
    config = function()
      local treesitter = require("nvim-treesitter")
      local installing = {}

      local function is_available(lang)
        return vim.tbl_contains(treesitter.get_available(), lang)
      end

      local function is_installed(lang)
        return vim.tbl_contains(treesitter.get_installed("parsers"), lang)
      end

      local function start(buf, lang)
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end

        if pcall(vim.treesitter.start, buf, lang) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      treesitter.setup()

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local ok, lang = pcall(vim.treesitter.language.get_lang, args.match)
          if not ok or not lang or not is_available(lang) then
            return
          end

          if is_installed(lang) then
            start(args.buf, lang)
            return
          end

          if type(installing[lang]) == "table" then
            table.insert(installing[lang], args.buf)
            return
          end

          installing[lang] = { args.buf }
          treesitter.install(lang, { max_jobs = 1 }):await(function(err)
            local buffers = installing[lang] or {}
            installing[lang] = nil
            if err then
              vim.schedule(function()
                vim.notify(("Failed to install tree-sitter parser for %s: %s"):format(lang, err), vim.log.levels.WARN)
              end)
              return
            end

            vim.schedule(function()
              for _, buf in ipairs(buffers) do
                start(buf, lang)
              end
            end)
          end)
        end,
      })
    end,
  },
}
