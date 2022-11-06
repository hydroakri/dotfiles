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

require'lspconfig'.clangd.setup{
    filetype = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
    capabilities = copy_capabilities,
    single_file_support = true,
    on_attach = custom_attach,
    cmd = {
        "clangd",
        "--background-index",
        "--pch-storage=memory",
        -- You MUST set this arg ↓ to your clangd executable location (if not included)!
        "--query-driver=/usr/bin/clang++,/usr/bin/**/clang-*,/bin/clang,/bin/clang++,/usr/bin/gcc,/usr/bin/g++",
        "--clang-tidy",
        "--all-scopes-completion",
        "--cross-file-rename",
        "--completion-style=detailed",
        "--header-insertion-decorators",
        "--header-insertion=iwyu",
    },
}
