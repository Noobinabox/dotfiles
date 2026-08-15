local spelling = require("config.spelling")

local codebook_filetypes = {
  "c",
  "css",
  "gitcommit",
  "go",
  "haskell",
  "html",
  "java",
  "javascript",
  "javascriptreact",
  "lua",
  "php",
  "python",
  "ruby",
  "rust",
  "swift",
  "toml",
  "text",
  "typescript",
  "typescriptreact",
  "zig",
}

local mason_servers = {
  clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "--clang-tidy",
      "--completion-style=detailed",
      "--header-insertion=iwyu",
      "--query-driver=/usr/bin/g++,/usr/bin/gcc",
    },
  },
  codebook = {
    filetypes = codebook_filetypes,
    init_options = {
      globalConfigPath = spelling.codebook_config,
    },
  },
  harper_ls = {
    filetypes = {
      "markdown",
    },
    settings = {
      ["harper-ls"] = {
        userDictPath = spelling.spellfile,
      },
    },
  },
  lua_ls = {
    settings = {
      Lua = {
        completion = {
          callSnippet = "Replace",
        },
        diagnostics = {
          globals = { "vim" },
        },
        telemetry = {
          enable = false,
        },
        workspace = {
          checkThirdParty = false,
        },
      },
    },
  },
  marksman = {},
  omnisharp = {},
  pyright = {},
  ts_ls = {
    init_options = {
      maxTsServerMemory = 6144,
    },
  },
}

local function tintin_lsp_cmd()
  local executable = vim.fn.exepath("tintin-lsp")
  if executable ~= "" then
    return executable
  end

  local home_executable = vim.fn.expand("~/.local/bin/tintin-lsp")
  if vim.fn.executable(home_executable) == 1 then
    return home_executable
  end

  local source = debug.getinfo(1, "S").source
  if vim.startswith(source, "@") then
    local source_path = source:sub(2)
    local real_source_path = vim.uv.fs_realpath(source_path) or source_path
    local source_executable =
      vim.fn.fnamemodify(real_source_path, ":h:h:h:h:h:h") .. "/tools/.local/bin/tintin-lsp"
    if vim.fn.executable(source_executable) == 1 then
      return source_executable
    end
  end

  local repo_executable =
    vim.fn.fnamemodify(vim.fn.stdpath("config") .. "/../../../tools/.local/bin/tintin-lsp", ":p")
  if vim.fn.executable(repo_executable) == 1 then
    return repo_executable
  end

  return "tintin-lsp"
end

local custom_servers = {
  tintin_lsp = {
    cmd = { tintin_lsp_cmd() },
    filetypes = { "tintin" },
  },
}

local servers = vim.tbl_extend("force", mason_servers, custom_servers)
local mason_server_names = vim.tbl_keys(mason_servers)

return {
  {
    "mason-org/mason.nvim",
    cmd = {
      "Mason",
      "MasonInstall",
      "MasonLog",
      "MasonUninstall",
      "MasonUninstallAll",
      "MasonUpdate",
    },
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    cmd = {
      "LspInstall",
      "LspUninstall",
    },
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
    },
    opts = {
      ensure_installed = mason_server_names,
      automatic_enable = false,
    },
    config = function(_, opts)
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      capabilities.textDocument = capabilities.textDocument or {}
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }

      local function add_startup_progress(server, config)
        local before_init = config.before_init
        local on_init = config.on_init

        config.before_init = function(params, client_config)
          local ok, progress = pcall(require, "fidget.progress")
          if ok then
            client_config._startup_progress = progress.handle.create({
              title = "LSP",
              message = ("Starting %s"):format(server),
              lsp_client = { name = server },
              percentage = 0,
            })
          end

          vim.notify(("LSP starting: %s"):format(server), vim.log.levels.INFO, { title = "LSP" })

          if before_init then
            return before_init(params, client_config)
          end
        end

        config.on_init = function(client, initialize_result)
          local handle = client.config and client.config._startup_progress
          if handle then
            handle.message = ("Ready %s"):format(client.name)
            handle:finish()
            client.config._startup_progress = nil
          end

          vim.notify(("LSP ready: %s"):format(client.name), vim.log.levels.INFO, { title = "LSP" })

          if on_init then
            return on_init(client, initialize_result)
          end
        end
      end

      for server, config in pairs(servers) do
        config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, config.capabilities or {})
        add_startup_progress(server, config)
        vim.lsp.config(server, config)
        vim.lsp.enable(server)
      end

      require("mason-lspconfig").setup(opts)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    cmd = "LspInfo",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          local function map(keys, fn, desc, mode)
            vim.keymap.set(mode or "n", keys, fn, { buffer = event.buf, desc = desc })
          end

          local function format()
            local ok, conform = pcall(require, "conform")
            if ok then
              conform.format({ async = true, lsp_format = "fallback" })
              return
            end

            vim.lsp.buf.format({ async = true })
          end

          local function source_action()
            vim.lsp.buf.code_action({
              context = {
                diagnostics = vim.diagnostic.get(event.buf),
                only = { "source" },
              },
            })
          end

          map("K", vim.lsp.buf.hover, "LSP hover")
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("gr", vim.lsp.buf.references, "Go to references")

          map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "v" })
          map("<leader>cA", source_action, "Source action")
          map("<leader>cc", vim.lsp.codelens.run, "Run codelens", { "n", "v" })
          map("<leader>cC", vim.lsp.codelens.refresh, "Refresh codelens")
          map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
          map("<leader>cf", format, "Format")
          map("<leader>cl", "<cmd>LspInfo<CR>", "LSP info")
          map("<leader>cr", vim.lsp.buf.rename, "Rename")

          map("<leader>lr", vim.lsp.buf.rename, "LSP rename")
          map("<leader>la", vim.lsp.buf.code_action, "LSP code action")
          map("<leader>lf", format, "LSP format")

          if client and client.name == "clangd" then
            map("<leader>ch", "<cmd>LspClangdSwitchSourceHeader<CR>", "Switch source/header")
            map("<leader>cI", "<cmd>LspClangdShowSymbolInfo<CR>", "Show symbol info")
          end

          map("[d", function()
            vim.diagnostic.jump({ count = -1, float = true })
          end, "Previous diagnostic")
          map("]d", function()
            vim.diagnostic.jump({ count = 1, float = true })
          end, "Next diagnostic")
        end,
      })
    end,
  },
}
