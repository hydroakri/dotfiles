-- bootstrap lazy
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- utf8
vim.g.encoding = "UTF-8"
vim.o.fileencoding = 'utf-8'
-- jk移动时光标下上方保留8行
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
-- 使用相对行号
vim.wo.number = true
vim.wo.relativenumber = true
-- 高亮所在行
vim.wo.cursorline = true
-- 显示左侧图标指示列
vim.wo.signcolumn = "yes"
-- 右侧参考线，超过表示代码太长了，考虑换行
-- vim.wo.colorcolumn = "80"
-- 缩进2个空格等于一个Tab
vim.o.tabstop = 4
vim.bo.tabstop = 4
-- >> << 时移动长度
vim.o.shiftwidth = 4
vim.bo.shiftwidth = 4
-- 新行对齐当前行，空格替代tab
vim.o.expandtab = true
vim.bo.expandtab = true
vim.o.autoindent = true
vim.bo.autoindent = true
vim.o.smartindent = true
-- 搜索大小写不敏感，除非包含大写
vim.o.ignorecase = true
vim.o.smartcase = true
-- 搜索不要高亮
vim.o.hlsearch = false
-- 边输入边搜索
vim.o.incsearch = true
-- 使用增强状态栏后不再需要 vim 的模式提示
vim.o.showmode = false
-- 命令行高为2，提供足够的显示空间
vim.o.cmdheight = 1
-- 当文件被外部程序修改时，自动加载
vim.o.autoread = true
vim.bo.autoread = true
-- 禁止折行
vim.o.wrap = true
vim.wo.wrap = true
-- 允许隐藏被修改过的buffer
vim.o.hidden = true
-- 鼠标支持
vim.o.mouse = "a"
-- 禁止创建备份文件
vim.o.backup = false
vim.o.writebackup = false
vim.o.swapfile = false
-- 自动补全不自动选中
vim.g.completeopt = "menu,menuone,noselect,noinsert"
-- 样式
vim.o.background = "dark"
vim.o.termguicolors = true
vim.opt.termguicolors = true
-- 不可见字符的显示，这里只把空格显示为一个点
vim.o.list = true
vim.o.listchars = "space:⋅"
vim.o.listchars = "tab:=="
vim.opt.clipboard = unnamedplus --see :help clipboard
vim.opt.cmdheight = 0

-- font
vim.g.gui_font_default_size = 14
--vim.g.gui_font_size = vim.g.gui_font_default_size
vim.g.gui_font_face = "FiraCode Nerd Font"

RefreshGuiFont = function()
    vim.opt.guifont = string.format("%s:h%s",vim.g.gui_font_face, vim.g.gui_font_size)
end

ResizeGuiFont = function(delta)
    vim.g.gui_font_size = vim.g.gui_font_size + delta
    RefreshGuiFont()
end

ResetGuiFont = function()
    vim.g.gui_font_size = vim.g.gui_font_default_size
    RefreshGuiFont()
end
-- Call function on startup to set default value
ResetGuiFont()


-- Keymaps
local opts = { noremap = true, silent = true }
vim.keymap.set({'n', 'i'}, "<C-=>", function() ResizeGuiFont(1)  end, opts)
vim.keymap.set({'n', 'i'}, "<C-->", function() ResizeGuiFont(-1) end, opts)
-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 保存本地变量
local map = vim.api.nvim_set_keymap
local opt = { noremap = true, silent = true }
-- 之后就可以这样映射按键了
-- map('模式','按键','映射为XX',opt)

-- split windows
map("n", "<Leader>\\", ":vsp<CR>", opt)
map("n", "<Leader>-", ":sp<CR>", opt)

-- windows jump
map("n", "<Leader>h", "<C-w>h", opt)
map("n", "<Leader>j", "<C-w>j", opt)
map("n", "<Leader>k", "<C-w>k", opt)
map("n", "<Leader>l", "<C-w>l", opt)
map("n", "<Leader>q", "<C-w>q", opt)

-- Telescope
map("n", "<Leader>ff", ":Telescope fd hidden=true<CR>", opt)
map("n", "<Leader>fh", ":Telescope oldfiles<CR>", opt)
map("n", "<leader>g", ":Telescope live_grep<CR>", opt)
map("n", "<leader>t", ":Telescope<CR>", opt)

-- nvimTree
map('n', 't', ':NvimTreeFindFileToggle<CR>', opt)

-- bufferline 左右切换
-- map("n", "<A-h>", ":BufferLineCyclePrev<CR>", opt)
map("n", "<S-j>", ":BufferLineCyclePrev<CR>", opt)
map("n", "<S-k>", ":BufferLineCycleNext<CR>", opt)
map("n", "<Leader>b", ":BufferLinePickClose<CR>", opt)

-- toggleterm
map('n', ".", ":ToggleTerm direction=float<CR>", opt)
map('t', "<Esc>", "<C-\\><C-n><cmd>ToggleTerm direction=float<CR>", opt)

-- tagbar
map('n', "<Leader>o", ":SymbolsOutline<CR>", opt)

-- trouble
map('n', "<Leader>x", "<cmd>TroubleToggle<CR>", opt)

-- Session manager
map('n', "<Leader>sl", ":SessionManager load_session<CR>", opt)
map('n', "<Leader>ss", ":SessionManager save_current_session<CR>", opt)
map('n', "<Leader>sd", ":SessionManager delete_session<CR>", opt)
-- debug
map("n", "<leader>db", "<cmd>lua require'dap'.toggle_breakpoint()<cr>", opt)
map("n", "<leader>dB", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input '[Condition] > ')<cr>", opt)
-- map("n", "<leader>dr", "lua require'dap'.repl.open()<cr>", opt)
map("n", "<F9>", "<cmd>lua require'dap'.run_last()<cr>", opt)
map("n", "<F4>", "<cmd>lua require'dap'.terminate()<cr>", opt)
map("n", "<F5>", "<cmd>lua require'dap'.continue()<cr>", opt)
map("n", "<F6>", "<cmd>lua require'dap'.step_over()<cr>", opt)
map("n", "<F7>", "<cmd>lua require'dap'.step_into()<cr>", opt)
map("n", "<F8>", "<cmd>lua require'dap'.step_out()<cr>", opt)
-- map("n", "<leader>dt", "<cmd>lua require'dapui'.toggle()<cr>", opt)
-- map("n", "<leader>dx", "<cmd>lua require'dap'.terminate()<cr>", opt)

-- install plugins
require("lazy").setup({
    { 'Mofiqul/dracula.nvim' },
    { "catppuccin/nvim", name = "catppuccin" },
    { 'nvim-telescope/telescope.nvim', version="0.1.1", dependencies='nvim-lua/plenary.nvim' },
    { 'nvim-tree/nvim-tree.lua', version='nightly', dependencies='nvim-tree/nvim-web-devicons' },
    { 'akinsho/bufferline.nvim', version='v3.*', dependencies='nvim-tree/nvim-web-devicons' },
    { 'nvim-lualine/lualine.nvim' },
    { 'nvim-treesitter/nvim-treesitter', build=':TSUpdate' },
    { "akinsho/toggleterm.nvim", version='*' },
    { 'Shatur/neovim-session-manager' },
    { 'folke/which-key.nvim', config = function() vim.o.timeout = true vim.o.timeoutlen = 300 require("which-key").setup() end },
    { 'neovim/nvim-lspconfig' },
    { 'williamboman/mason.nvim' },
    { 'mfussenegger/nvim-dap' },
    { 'ms-jpq/coq_nvim', version='coq' },
    { 'ms-jpq/coq.artifacts', version='artifacts' },
    { 'ms-jpq/coq.thirdparty', version='3p' },
    { 'simrat39/symbols-outline.nvim' },
    { "iamcco/markdown-preview.nvim", build = function() vim.fn["mkdp#util#install"]() end },
    { 'lukas-reineke/indent-blankline.nvim' },
    { 'karb94/neoscroll.nvim' },
    { 'mg979/vim-visual-multi', version='master' },
    { 'nvim-treesitter/nvim-treesitter-context' },
    { 'steelsojka/pears.nvim' },
    { 'wellle/targets.vim' },
    { 'folke/trouble.nvim' },
    { 'ggandor/leap.nvim' },
    { 'RRethy/vim-illuminate' },
    { 'norcalli/nvim-colorizer.lua' },
    { 'lewis6991/gitsigns.nvim' },
    { 'folke/noice.nvim', dependencies={'MunifTanjim/nui.nvim','rcarriga/nvim-notify'} },
    { 'lambdalisue/suda.vim' },
    { "ziontee113/color-picker.nvim" },
    { 'numToStr/Comment.nvim' },
    { 'nvim-telescope/telescope-fzf-native.nvim', build='make' },

})

vim.cmd.colorscheme "dracula"


-- plugins config
require("colorizer").setup()
require('leap').add_default_mappings()
require("trouble").setup()
require("pears").setup()
require("neoscroll").setup()
require("toggleterm").setup()
require("symbols-outline").setup()
require('nvim-tree').setup()
require("trouble").setup()
require('treesitter-context').setup()
require('gitsigns').setup()
require('noice').setup()
require("color-picker").setup()
require('Comment').setup()

local telescopeConfig = require("telescope.config")
-- Clone the default Telescope configuration
local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }
-- I want to search in hidden/dot files.
table.insert(vimgrep_arguments, "--hidden")
-- I don't want to search in the `.git` directory.
table.insert(vimgrep_arguments, "--glob")
table.insert(vimgrep_arguments, "!**/.git/*")
require('telescope').setup{
    extensions = {
        fzf = {
            fuzzy = true,                    -- false will only do exact matching
            override_generic_sorter = true,  -- override the generic sorter
            override_file_sorter = true,     -- override the file sorter
            case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
            -- the default case_mode is "smart_case"
        }
    },
    defaults = {
        -- `hidden = true` is not supported in text grep commands.
        vimgrep_arguments = vimgrep_arguments,
    },
    pickers = {
        find_files = {
            find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
        },
    },
}

require('lualine').setup{
    options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = '' },
    section_separators = { left = ' ', right = ' '},
    -- component_separators = { left = '', right = '' },
    -- section_separators = { left = '', right = ''},
    -- section_separators = { left = '', right = '' },
    -- component_separators = { left = '', right = ''},
    -- component_separators = { left = '', right = ''},
    -- section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
require("indent_blankline").setup {
    -- for example, context is off by default, use this to turn it on
    show_current_context = true,
    show_current_context_start = true,
}
-- --dap
require('dap').adapters.cppdbg = {
    id = 'cppdbg',
    type = 'executable',
    command = '/home/hydroakri/.local/share/nvim/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7',
}
require('dap').configurations.cpp = {
    {
        name = "Launch file",
        type = "cppdbg",
        request = "launch",
        program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
        end,
        cwd = '${workspaceFolder}',
        stopAtEntry = true,
    },
    {
        name = 'Attach to gdbserver :1234',
        type = 'cppdbg',
        request = 'launch',
        MIMode = 'gdb',
        miDebuggerServerAddress = 'localhost:1234',
        miDebuggerPath = '/usr/bin/gdb',
        cwd = '${workspaceFolder}',
        program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
        end,
    },
}


-- --lsp language config
require("mason").setup{}
-- after local capabilities = ....
-- start server
-- 配置方法详见 https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
require("lspconfig").sumneko_lua.setup {
    require("coq").lsp_ensure_capabilities,
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


require("lspconfig").pyright.setup {
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
    single_file_support = true,
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

require("bufferline").setup {
    options = {
        -- 使用 nvim 内置lsp
        diagnostics = "nvim_lsp",
        -- 左侧让出 nvim-tree 的位置
        offsets = {{
            filetype = "NvimTree",
            text = "File Explorer",
            highlight = "Directory",
            text_align = "left"
        }}
    }
}


require'nvim-treesitter.configs'.setup {
    -- 安装 language parser
    -- :TSInstallInfo 命令查看支持的语言
    ensure_installed = {"python", "cpp", "c", "html", "css", "vim", "lua", "javascript", "typescript", "tsx"},
    -- 启用代码高亮功能
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false
    },
    -- 启用增量选择
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = '<CR>',
            node_incremental = '<CR>',
            node_decremental = '<BS>',
            scope_incremental = '<TAB>',
        }
    },
    -- 启用基于Treesitter的代码格式化(=) . NOTE: This is an experimental feature.
    indent = {
        enable = true
    }
}
-- 开启 Folding
vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'nvim_treesitter#foldexpr()'
-- 默认不要折叠
-- https://stackoverflow.com/questions/8316139/how-to-set-the-default-to-unfolded-when-you-open-a-file
vim.wo.foldlevel = 99
