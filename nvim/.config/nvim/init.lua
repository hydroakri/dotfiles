-- Packer插件管理
require('plugins')
-- 基础配置文件
require('basic')
-- 快捷键
require('keybind')
-- 插件配置
require('plug/nvim-tree')
require('plug/bufferline')
require('plug/nvim-treesitter')
require('plug/lualine')
require('plug/telescope')
require('plug/trouble')
-- dap
require('dap/dap-ui')
require('dap/languages')
-- lsp
require('lsp/nvim-lspconfig')
require('lsp/mason')
require('lsp/languages')
