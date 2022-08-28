require("mason").setup{}
local lspconfig = require("lspconfig")
local coq = require "coq"
-- after local capabilities = ....
-- start server
-- 配置方法详见 https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
lspconfig.sumneko_lua.setup {
  coq.lsp_ensure_capabilities,
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
      },
      diagnostics = {
        globals = {"vim", "packer_bootstrap"},
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
      },
      telemetry = {
        enable = false,
      },
    },
  },
}

lspconfig.pyright.setup {
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "workspace",
        useLibraryCodeForTypes = true,
        typeCheckingMode = "off",
      }
    }
  },
}

lspconfig.clangd.setup {
}
