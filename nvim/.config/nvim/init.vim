" Packer插件管理
lua require('plugins')
" 基础配置文件
lua require('basic')
" 快捷键
lua require('keybind')
" 插件配置
lua require('plug-conf/nvim-tree')
lua require('plug-conf/bufferline')
lua require('plug-conf/nvim-treesitter')
lua require('plug-conf/lualine')
lua require('plug-conf/telescope')
lua require('plug-conf/alpha-nvim')
lua require('plug-conf/trouble')
" lsp
lua require('lsp/nvim-lspconfig')
lua require('lsp/mason')
lua require('lsp/languages')

set clipboard=unnamedplus
set guifont=Sarasa\ Mono\ SC\ Nerd:14
set background=dark
colorscheme dracula

