return {
  -- LSP installer
  {
    "williamboman/mason.nvim",
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  -- Bridge mason <-> lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "lua_ls", "clangd", "pyright", "html", "cssls",
        "bashls", "jsonls", "ts_ls", "gopls",
      },
      automatic_enable = {
        exclude = { "rust_analyzer" },  -- rustaceanvim handles this
      },
    },
  },

  -- LSP core (nvim 0.12+ uses vim.lsp.config / vim.lsp.enable)
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      -- Global LSP keymaps on attach
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
        callback = function(ev)
          local bmap = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
          end
          bmap("n", "gd", vim.lsp.buf.definition, "Go to definition")
          bmap("n", "gr", vim.lsp.buf.references, "References")
          bmap("n", "gy", vim.lsp.buf.type_definition, "Type definition")
          bmap("n", "gi", vim.lsp.buf.implementation, "Implementation")
          bmap("n", "K", vim.lsp.buf.hover, "Hover documentation")
          bmap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          bmap("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          bmap("n", "<leader>cl", vim.lsp.codelens.run, "Code lens")
          bmap("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
          bmap("n", "[g", vim.diagnostic.goto_prev, "Prev diagnostic")
          bmap("n", "]g", vim.diagnostic.goto_next, "Next diagnostic")
          bmap("n", "<space>a", vim.diagnostic.setloclist, "Diagnostics to loclist")
        end,
      })

      -- Per-server configs (vim.lsp.config is native in nvim 0.12)
      vim.lsp.config("clangd", {
        cmd = { "clangd", "--background-index", "--clang-tidy" },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("pyright", {
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "off",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticSeverityOverrides = {
                reportUnusedImport = "none",
                reportUnusedVariable = "none",
                reportUnusedClass = "none",
                reportUnusedFunction = "none",
                reportMissingModuleSource = "none",
                reportMissingImports = "none",
                reportUndefinedVariable = "warning",
                reportGeneralClassIssues = "none",
                reportOptionalMemberAccess = "none",
                reportOptionalSubscript = "none",
                reportOptionalCall = "none",
                reportOptionalIterable = "none",
                reportOptionalContextManager = "none",
                reportOptionalOperand = "none",
              },
            },
          },
        },
      })

      vim.lsp.config("jsonls", {
        settings = { json = { validate = { enable = true } } },
      })

      vim.lsp.config("gopls", {
        settings = {
          gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
          },
        },
      })

      vim.lsp.config("ts_ls", {})
      vim.lsp.config("html", {})
      vim.lsp.config("cssls", {})
      vim.lsp.config("bashls", {})
    end,
  },

  -- Enhanced Rust support (replaces rust-analyzer from mason)
  {
    "mrcjkb/rustaceanvim",
    version = "^6",
    lazy = false,
    config = function()
      vim.g.rustaceanvim = {
        server = {
          default_settings = {
            ["rust-analyzer"] = {
              checkOnSave = { command = "clippy" },
            },
          },
        },
      }
    end,
  },

  -- LSP UI enhancement
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    opts = {
      symbol_in_winbar = { enable = true },
      lightbulb = { enable = false },
    },
  },
}
