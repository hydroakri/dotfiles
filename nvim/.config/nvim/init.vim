" Packer插件管理
lua require('plugins')
" 基础配置文件
lua require('basic')
" 快捷键
lua require('keybind')
" 插件配置
lua require('plug/nvim-tree')
lua require('plug/bufferline')
lua require('plug/nvim-treesitter')
lua require('plug/lualine')
lua require('plug/telescope')
lua require('plug/trouble')
lua require('plug/lspsaga')
" dap
lua require('dap/dap-ui')
lua require('dap/languages')
" lsp
lua require('lsp/nvim-lspconfig')
lua require('lsp/mason')
lua require('lsp/languages')

set clipboard=unnamedplus
set background=dark
" colorscheme dracula
" colorscheme catppuccin-frappe
colorscheme NeoSolarized
