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
vim.o.fileencoding = "utf-8"
-- jk移动时光标下上方保留8行
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
-- 使用相对行号
vim.wo.number = true
vim.wo.relativenumber = true
-- 高亮所在行
vim.wo.cursorline = true
vim.wo.cursorcolumn = true
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
vim.o.hlsearch = true
-- 边输入边搜索
vim.o.incsearch = true
-- 使用增强状态栏后不再需要 vim 的模式提示
vim.o.showmode = false
-- 命令行高为2，提供足够的显示空间
vim.o.cmdheight = 0
-- 当文件被外部程序修改时，自动加载
vim.o.autoread = true
vim.bo.autoread = true
-- 禁止折行
vim.o.wrap = true
vim.wo.wrap = true
vim.wo.linebreak = true
vim.wo.list = false -- extra option I set in addition to the ones in your question
-- 允许隐藏被修改过的buffer
vim.o.hidden = true
-- 鼠标支持
vim.o.mouse = "a"
-- 禁止创建备份文件
vim.o.backup = false
vim.o.writebackup = false
vim.o.swapfile = false
-- 自动补全不自动选中
--vim.g.completeopt = "menu,menuone,noselect,noinsert"
-- 样式
vim.o.background = "dark"
vim.o.termguicolors = true
vim.opt.termguicolors = true
-- 不可见字符的显示，这里只把空格显示为一个点
vim.opt.list = true
vim.opt.listchars = { space = " ", tab = "> ", eol = "↵" }
vim.opt.clipboard = unamedplus --see :help clipboard
vim.opt.cmdheight = 0
-- 开启 Folding
vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "nvim_treesitter#foldexpr()"
-- 默认不要折叠
-- https://stackoverflow.com/questions/8316139/how-to-set-the-default-to-unfolded-when-you-open-a-file
vim.wo.foldlevel = 99

-- font
vim.opt.guifont = { "Hack_Nerd_Font", ":h12" }

-- keybind
local map = vim.api.nvim_set_keymap
local opt = { noremap = true, silent = true }

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- package manager
map("n", "<leader>pu", ":Lazy update<CR>", opt)
map("n", "<leader>pm", ":Mason<CR>", opt)
map("n", "<leader>pl", ":LspInfo<CR>", opt)

-- Navigation
map("n", "<C-h>", "<C-w>h", opt)
map("n", "<C-j>", "<C-w>j", opt)
map("n", "<C-k>", "<C-w>k", opt)
map("n", "<C-l>", "<C-w>l", opt)
map("n", "<C-q>", "<C-w>q", opt)
-- Resize with arrows
map("n", "<C-Up>", ":resize -2<CR>", opt)
map("n", "<C-Down>", ":resize +2<CR>", opt)
map("n", "<C-Left>", ":vertical resize -2<CR>", opt)
map("n", "<C-Right>", ":vertical resize +2<CR>", opt)
-- bufferline 左右切换
map("n", "<S-h>", ":BufferLineCyclePrev<CR>", opt)
map("n", "<S-l>", ":BufferLineCycleNext<CR>", opt)
map("n", "<Leader>b", ":BufferLinePickClose<CR>", opt)
-- tabpage 切换
map("n", "<S-j>", ":tabprevious<CR>", opt)
map("n", "<S-k>", ":tabnext<CR>", opt)
-- Move text up and down
map("n", "<A-j>", "<Esc>:m .+1<CR>==gi<Esc>", opt)
map("n", "<A-k>", "<Esc>:m .-2<CR>==gi<Esc>", opt)

-- search
map("n", "<Leader>sf", ":Telescope fd hidden=true<CR>", opt)
map("n", "<Leader>so", ":Telescope oldfiles<CR>", opt)
map("n", "<leader>sg", ":Telescope live_grep<CR>", opt)

-- toggle
map("n", "<leader>tf", ":NvimTreeFindFileToggle<CR>", opt)
map("n", "<leader>tt", ":ToggleTerm direction=tab<CR>", opt)
map("n", "<leader>tg", ":Telescope<CR>", opt)
map("t", "<Esc>", "<C-\\><C-n>", opt)
map("n", "<leader>tsl", ":SessionManager load_session<CR>", opt)
map("n", "<leader>tsd", ":SessionManager delete_session<CR>", opt)
map("n", "<leader>tm", ":MinimapToggle<CR>", opt)

-- git
map("n", "<leader>gj", ":Gitsigns next_hunk<CR>", opt)
map("n", "<leader>gk", ":Gitsigns prev_hunk<CR>", opt)
map("n", "<leader>gl", ":Gitsigns blame_line<CR>", opt)
map("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", opt)
map("n", "<leader>gd", ":DiffviewOpen<CR>", opt)

-- debug
map("n", "<leader>dp", "<cmd>lua require'dap'.toggle_breakpoint()<cr>", opt)
map("n", "<leader>dP", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input '[Condition] > ')<cr>", opt)
map("n", "<leader>dc", "<cmd>lua require'dap'.continue()<cr>", opt)
map("n", "<leader>dx", "<cmd>lua require'dap'.step_over()<cr>", opt)
map("n", "<leader>di", "<cmd>lua require'dap'.step_into()<cr>", opt)
map("n", "<leader>du", "<cmd>lua require'dap'.repl.open()<cr>", opt)
-- map("n", "<leader>dt", "<cmd>lua require'dapui'.toggle()<cr>", opt)
-- map("n", "<leader>dx", "<cmd>lua require'dap'.terminate()<cr>", opt)

-- lsp keybind begin --
map("n", "<Leader>lf", "<cmd>Neoformat<CR>", opt)
map("n", "<Leader>ls", ":SymbolsOutline<CR>", opt)
map("n", "<Leader>lx", ":TroubleToggle workspace_diagnostics<CR>", opt)
map("n", "<Leader>lr", ":TroubleToggle lsp_references<CR>", opt)
map("n", "<Leader>lD", ":TroubleToggle lsp_type_definitions<CR>", opt)
map("n", "<Leader>ld", ":TroubleToggle lsp_definitions<CR>", opt)
map("n", "<Leader>li", ":TroubleToggle lsp_implementations<CR>", opt)

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		-- Enable completion triggered by <c-x><c-o>
		vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

		-- Buffer local mappings.
		-- See `:help vim.lsp.*` for documentation on any of the below functions
		local opts = { buffer = ev.buf }
		vim.keymap.set("n", "<Leader>lh", vim.lsp.buf.signature_help, opts)
		vim.keymap.set("n", "<Leader>ln", vim.lsp.buf.rename, opts)
		vim.keymap.set("n", "<Leader>la", vim.lsp.buf.code_action, opts)
		vim.keymap.set("n", "<Leader>lwa", vim.lsp.buf.add_workspace_folder, opts)
		vim.keymap.set("n", "<Leader>lwr", vim.lsp.buf.remove_workspace_folder, opts)
		vim.keymap.set("n", "<Leader>lwl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, opts)
	end,
})
-- lsp keybind end --

-- install plugins
require("lazy").setup({
    -- colorscheme
	{ "catppuccin/nvim", name = "catppuccin" },
	{ "rebelot/kanagawa.nvim" },
	{ "navarasu/onedark.nvim" },
    -- lsp/completion/dap/spellcheck
	{ "hrsh7th/cmp-nvim-lsp" },
	{ "hrsh7th/cmp-buffer" },
	{ "hrsh7th/cmp-path" },
	{ "hrsh7th/cmp-cmdline" },
	{ "hrsh7th/nvim-cmp" },
	{ "hrsh7th/cmp-vsnip" },
	{ "hrsh7th/vim-vsnip" },
	{ "neovim/nvim-lspconfig" },
	{ "williamboman/mason.nvim", config = true },
	{ "williamboman/mason-lspconfig.nvim", config = true },
	{ "Exafunction/codeium.vim" },
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
	{ "nvim-treesitter/nvim-treesitter-context", config = true },
	{ "folke/trouble.nvim", config = true },
	{ "simrat39/symbols-outline.nvim", config = true },
	{ "sbdchd/neoformat" },
	{ "mfussenegger/nvim-dap" },
    -- basic ide
	{ "nvim-telescope/telescope.nvim", version = "0.1.1", dependencies = "nvim-lua/plenary.nvim" },
	{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	{ "nvim-tree/nvim-tree.lua", version = "nightly", dependencies = "nvim-tree/nvim-web-devicons" },
	{ "akinsho/bufferline.nvim", version = "v3.*", dependencies = "nvim-tree/nvim-web-devicons" },
	{ "akinsho/toggleterm.nvim", version = "*", config = true },
	{ "sindrets/diffview.nvim" },
	{ "lewis6991/gitsigns.nvim", config = true },
	{ "lukas-reineke/indent-blankline.nvim", config = true },
	{ "petertriho/nvim-scrollbar", config = true },
	{ "nvim-lualine/lualine.nvim", config = true },
	{ "RRethy/vim-illuminate" },
	{ "mg979/vim-visual-multi", version = "*" },
	{ "lambdalisue/suda.vim" },
	{ "Shatur/neovim-session-manager" },
	{ "ggandor/leap.nvim", config = true },
	{ "folke/which-key.nvim", config = true },
	{ "numToStr/Comment.nvim", config = true },
	{ "windwp/nvim-autopairs", config = true },
	{ "norcalli/nvim-colorizer.lua", config = true },
	{ "ziontee113/color-picker.nvim", config = true },
	{
		"iamcco/markdown-preview.nvim",
		build = function()
			vim.fn["mkdp#util#install"]()
		end,
	},
	--{ "folke/noice.nvim", dependencies = { "MunifTanjim/nui.nvim", --[[ "rcarriga/nvim-notify" ]] }, config = true },
})

vim.cmd.colorscheme("kanagawa-dragon")
-- plugins config
require("leap").add_default_mappings()

require("nvim-tree").setup({
	view = {
		width = 20,
	},
})

-- cmp config begin
local cmp = require("cmp")
cmp.setup({
	snippet = {
		-- REQUIRED - you must specify a snippet engine
		expand = function(args)
			vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
			-- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
			-- require('snippy').expand_snippet(args.body) -- For `snippy` users.
			-- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
		end,
	},
	window = {
		-- completion = cmp.config.window.bordered(),
		-- documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
		["<C-u>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "vsnip" }, -- For vsnip users.
		-- { name = 'luasnip' }, -- For luasnip users.
		-- { name = 'ultisnips' }, -- For ultisnips users.
		-- { name = 'snippy' }, -- For snippy users.
	}, {
		{ name = "buffer" },
	}),
})

-- Set configuration for specific filetype.
cmp.setup.filetype("gitcommit", {
	sources = cmp.config.sources({
		{ name = "cmp_git" }, -- You can specify the `cmp_git` source if you were installed it.
	}, {
		{ name = "buffer" },
	}),
})

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ "/", "?" }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = "buffer" },
	},
})
-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
})
-- Set up lspconfig.
-- 配置方法详见 https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
local capabilities = require("cmp_nvim_lsp").default_capabilities()
-- cmp config end --
require("mason-lspconfig").setup_handlers({
	function(server_name)
		require("lspconfig")[server_name].setup({
			capabilities = capabilities,
		})
	end,

	["lua_ls"] = function()
		require("lspconfig").lua_ls.setup({
			capabilities = capabilities,
			settings = {
				Lua = {
					runtime = {
						version = "LuaJIT",
					},
					diagnostics = {
						globals = { "vim", "packer_bootstrap" },
					},
					telemetry = {
						enable = false,
					},
				},
			},
		})
	end,

	["clangd"] = function()
		require("lspconfig").clangd.setup({
			capabilities = capabilities,
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
		})
	end,
})

-- indent blank begin --
vim.cmd([[highlight line1 guifg=#E06C75 gui=nocombine]])
vim.cmd([[highlight line2 guifg=#E5C07B gui=nocombine]])
vim.cmd([[highlight line3 guifg=#98C379 gui=nocombine]])
vim.cmd([[highlight line4 guifg=#56B6C2 gui=nocombine]])
vim.cmd([[highlight line5 guifg=#61AFEF gui=nocombine]])
vim.cmd([[highlight line6 guifg=#C678DD gui=nocombine]])
require("indent_blankline").setup({
	space_char_blankline = " ",
	char_highlight_list = {
		"line1",
		"line2",
		"line3",
		"line4",
		"line5",
		"line6",
	},
})
-- indent blank end --

local telescope = require("telescope")
local telescopeConfig = require("telescope.config")
local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }
table.insert(vimgrep_arguments, "--hidden")
table.insert(vimgrep_arguments, "--glob")
table.insert(vimgrep_arguments, "!**/.git/*")
telescope.setup({
	defaults = {
		vimgrep_arguments = vimgrep_arguments,
	},
	pickers = {
		find_files = {
			find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
		},
	},
})

require("lualine").setup({
	options = {
		icons_enabled = true,
		theme = "auto",
		component_separators = { left = " ", right = " " },
		section_separators = { left = " ", right = " " },
		-- component_separators = { left = '', right = '' },
		-- section_separators = { left = '', right = ''},
		-- section_separators = { left = '', right = '' },
		-- component_separators = { left = '', right = ''},
		-- component_separators = { left = '', right = ''},
		-- section_separators = { left = '', right = ''},
	},
})
-- --dap
require("dap").adapters.cppdbg = {
	id = "cppdbg",
	type = "executable",
	command = "~/.local/share/nvim/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7",
}
require("dap").configurations.cpp = {
	{
		name = "Launch file",
		type = "cppdbg",
		request = "launch",
		program = function()
			return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
		end,
		cwd = "${workspaceFolder}",
		stopAtEntry = true,
	},
	{
		name = "Attach to gdbserver :1234",
		type = "cppdbg",
		request = "launch",
		MIMode = "gdb",
		miDebuggerServerAddress = "localhost:1234",
		miDebuggerPath = "/usr/bin/gdb",
		cwd = "${workspaceFolder}",
		program = function()
			return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
		end,
	},
}

require("bufferline").setup({
	options = {
		indicator = {
			style = "underline",
		},
		diagnostics = "nvim_lsp",
		offsets = {
			{
				filetype = "NvimTree",
				text = "File Explorer",
				highlight = "Directory",
				text_align = "left",
				separator = true,
			},
		},
		enforce_regular_tabs = false,
		hover = {
			enabled = true,
			delay = 200,
			reveal = { "close" },
		},
	},
})

require("nvim-treesitter.configs").setup({
	ensure_installed = { "c", "lua", "vim", "help", "query" },
	auto_install = true,
	-- 启用代码高亮功能
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false,
	},
	-- 启用增量选择
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<CR>",
			node_incremental = "<CR>",
			node_decremental = "<BS>",
			scope_incremental = "<TAB>",
		},
	},
})
