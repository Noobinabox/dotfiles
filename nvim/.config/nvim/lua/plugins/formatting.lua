return {
  {
    "stevearc/conform.nvim",
    cmd = "ConformInfo",
    dependencies = {
      "mason-org/mason.nvim",
    },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "Format",
      },
    },
    opts = {
      formatters_by_ft = {
        c = { "clang_format" },
        cs = { "csharpier" },
        cmake = { "cmake_format" },
        cpp = { "clang_format" },
        javascript = { "eslint_curly" },
        javascriptreact = { "eslint_curly" },
        json = { "prettier" },
        markdown = { "prettier" },
        mdx = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
        typescript = { "eslint_curly" },
        typescriptreact = { "eslint_curly" },
      },
      formatters = {
        cmake_format = {
          command = vim.fn.stdpath("data") .. "/mason/bin/cmake-format",
        },
        csharpier = {
          append_args = {
            "--config-path",
            vim.fn.stdpath("config") .. "/.csharpierrc.json",
          },
        },
        eslint_curly = {
          format = function(_, ctx, lines, callback)
            local extension = vim.fn.fnamemodify(ctx.filename, ":e")
            if extension == "" then
              extension = "js"
            end

            local temp = vim.fn.tempname() .. "." .. extension
            vim.fn.writefile(lines, temp)

            vim.fn.system({
              "eslint",
              "--fix",
              "--no-eslintrc",
              "--no-ignore",
              "--config",
              vim.fn.stdpath("config") .. "/.eslintrc.json",
              temp,
            })

            vim.fn.system({
              vim.fn.stdpath("data") .. "/mason/bin/prettier",
              "--write",
              "--config",
              vim.fn.stdpath("config") .. "/.prettierrc.json",
              temp,
            })

            local fixed = vim.fn.readfile(temp)
            vim.fn.delete(temp)
            callback(nil, fixed)
          end,
        },
        prettier = {
          command = vim.fn.stdpath("data") .. "/mason/bin/prettier",
          stdin = true,
          prepend_args = {
            "--config",
            vim.fn.stdpath("config") .. "/.prettierrc.json",
          },
        },
      },
    },
  },
}
