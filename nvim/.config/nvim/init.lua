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
vim.g.completeopt = "menu,menuone,noselect,noinsert"
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
vim.o.foldcolumn = "1" -- '0' is not bad
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true
--vim.wo.foldmethod = "expr"
--vim.wo.foldexpr = "nvim_treesitter#foldexpr()"

-- font
vim.opt.guifont = { "Hack Nerd Font", ":h12" }

vim.g.indent_blankline_filetype_exclude = { "dashboard" }

-- ========================================== keybind ====================================
local map = vim.api.nvim_set_keymap
local opt = { noremap = true, silent = true }
-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- package manager
map("n", "<leader>pu", ":Lazy update<CR>", opt)
map("n", "<leader>pm", ":Mason<CR>", opt)
map("n", "<leader>pl", ":LspInfo<CR>", opt)
-- window
map("n", "<A-h>", "<C-w>h", opt)
map("n", "<A-j>", "<C-w>j", opt)
map("n", "<A-k>", "<C-w>k", opt)
map("n", "<A-l>", "<C-w>l", opt)
map("n", "<A-q>", "<C-w>q", opt)
map("n", "<A-v>", "<C-w>v", opt)
map("n", "<A-s>", "<C-w>s", opt)
map("n", "<A-Up>", ":horizontal resize -2<CR>", opt)
map("n", "<A-Down>", ":horizontal resize +2<CR>", opt)
map("n", "<A-Left>", ":vertical resize -2<CR>", opt)
map("n", "<A-Right>", ":vertical resize +2<CR>", opt)
-- accelerated-jk
map("n", "j", "<Plug>(accelerated_jk_gj)", opt)
map("n", "k", "<Plug>(accelerated_jk_gk)", opt)
-- bufferline 左右切换
map("n", "<S-h>", ":BufferLineCyclePrev<CR>", opt)
map("n", "<S-l>", ":BufferLineCycleNext<CR>", opt)
map("n", "<Leader>bp", ":BufferLinePick<CR>", opt)
map("n", "<Leader>bc", ":BufferLinePickClose<CR>", opt)
-- Move text up and down
map("n", "<A-u>", "<Esc>:m .+1<CR>==gi<Esc>", opt)
map("n", "<A-d>", "<Esc>:m .-2<CR>==gi<Esc>", opt)
-- search
map("n", "<Leader>sf", ":Telescope fd hidden=true<CR>", opt)
map("n", "<Leader>so", ":Telescope oldfiles<CR>", opt)
map("n", "<leader>sg", ":Telescope live_grep<CR>", opt)
-- toggle
map("n", "<leader>tf", ":NvimTreeFindFileToggle<CR>", opt)
map("n", "<leader>tt", ":ToggleTerm direction=horizontal<CR>i", opt)
map("t", "<Esc>", "<C-\\><C-n>:ToggleTerm<CR>", opt)
map("n", "<leader>tg", ":Telescope<CR>", opt)
map("n", "<leader>tsl", ":SessionManager load_session<CR>", opt)
map("n", "<leader>tsd", ":SessionManager delete_session<CR>", opt)
map("n", "<leader>tp", ":Telescope projects<CR>", opt)
map("n", "<leader>td", ":Dashboard<CR>", opt)
map("n", "<leader>tc", ":CccPick<CR>", opt)
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
-- lsp keybind
map("n", "<Leader>lf", "<cmd>Neoformat<CR>", opt)
map("n", "<Leader>ls", ":SymbolsOutline<CR>", opt)

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

--=========================================== plug install ===============================================
require("lazy").setup({
	-- colorscheme
	{ "catppuccin/nvim", name = "catppuccin" },
	{ "rebelot/kanagawa.nvim" },
	{ "folke/tokyonight.nvim", },
	{ "EdenEast/nightfox.nvim" },
	-- completion
	{ "hrsh7th/nvim-cmp", event = { "InsertEnter", "CmdlineEnter" } },
	{ "hrsh7th/cmp-nvim-lsp", event = "InsertEnter" },
	{ "hrsh7th/cmp-buffer", event = "InsertEnter" },
	{ "hrsh7th/cmp-path", event = "InsertEnter" },
	{ "hrsh7th/cmp-cmdline", event = "CmdlineEnter" },
	{ "hrsh7th/cmp-nvim-lsp-signature-help", event = "InsertEnter" },
	{ "ray-x/cmp-treesitter", event = "InsertEnter" },
	{ "Exafunction/codeium.vim", event = "BufEnter" },
	-- snips, friendly-snippets as provider
	{ "L3MON4D3/LuaSnip", dependencies = "rafamadriz/friendly-snippets", event = "InsertEnter" },
	{ "saadparwaiz1/cmp_luasnip", event = "InsertEnter" },
	-- lsp
	{ "neovim/nvim-lspconfig", event = "User FileOpened" },
	{ "williamboman/mason.nvim", config = true, event = "User FileOpened" },
	{ "williamboman/mason-lspconfig.nvim", config = true, event = "User FileOpened" },
	{ "simrat39/symbols-outline.nvim", config = true, event = "BufReadPre" },
	{ "j-hui/fidget.nvim", tag = "legacy", config = true, event = "BufReadPre" },
	{
		"ray-x/navigator.lua",
		dependencies = { { "ray-x/guihua.lua", build = "cd lua/fzy && make" }, { "neovim/nvim-lspconfig" } },
		config = true,
		event = "InsertEnter",
	},
	-- treesitter
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", event = "User FileOpened" },
	{ "nvim-treesitter/nvim-treesitter-context", config = true, event = "BufReadPre" },
	-- format
	{ "sbdchd/neoformat", event = "InsertEnter" },
	-- debug
	{ "mfussenegger/nvim-dap", event = "VeryLazy" },
	-- coderunner
	{ "michaelb/sniprun", build = "sh ./install.sh", event = "VeryLazy" },
	-- git
	{ "sindrets/diffview.nvim", event = "BufReadPre" },
	{ "lewis6991/gitsigns.nvim", config = true, event = "BufReadPre" },
	-- tools
	{ "nvim-telescope/telescope.nvim", version = "0.1.1", dependencies = "nvim-lua/plenary.nvim" },
	{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	{ "mg979/vim-visual-multi", version = "*", event = "InsertEnter" },
	{ "Shatur/neovim-session-manager", dependencies = "nvim-lua/plenary.nvim", event = "VeryLazy", config = true },
	{ "ahmedkhalf/project.nvim", event = "VimEnter" },
	{ "numToStr/Comment.nvim", config = true, event = "InsertEnter" },
	{ "windwp/nvim-autopairs", config = true, event = "InsertEnter" },
	{ "uga-rosa/ccc.nvim", config = true, event = "VeryLazy" },
	{ "lambdalisue/suda.vim" },
	-- user interface
	{ "nvim-tree/nvim-tree.lua", version = "nightly", dependencies = "nvim-tree/nvim-web-devicons" },
	{ "akinsho/bufferline.nvim", version = "v3.*", dependencies = "nvim-tree/nvim-web-devicons" },
	{ "nvim-lualine/lualine.nvim", config = true, event = "VimEnter" },
	{ "nvimdev/dashboard-nvim", config = true, event = "VimEnter" },
	{ "akinsho/toggleterm.nvim", version = "*", config = true, event = "BufEnter" },
	{ "lukas-reineke/indent-blankline.nvim", config = true, event = "BufEnter" },
	{ "petertriho/nvim-scrollbar", config = true, event = "VeryLazy" },
	{ "RRethy/vim-illuminate", event = "VimEnter" },
	{ "NvChad/nvim-colorizer.lua", config = true, event = "VeryLazy" },
	{ "karb94/neoscroll.nvim", config = true, event = "VeryLazy" },
	{ "kevinhwang91/nvim-ufo", config = true, dependencies = "kevinhwang91/promise-async", event = "VimEnter" },
	{
		"folke/which-key.nvim",
		config = true,
		event = "VeryLazy",
		init = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 0
		end,
	},
	-- language
	{
		"iamcco/markdown-preview.nvim",
		build = function()
			vim.fn["mkdp#util#install"]()
		end,
	},
	-- jump
	{ "rainbowhxch/accelerated-jk.nvim", event = "VeryLazy" },
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {},
		keys = {
			{
				"s",
				mode = { "n", "x", "o" },
				function()
					require("flash").jump()
				end,
				desc = "Flash",
			},
			{
				"S",
				mode = { "n", "o", "x" },
				function()
					require("flash").treesitter()
				end,
				desc = "Flash Treesitter",
			},
			{
				"r",
				mode = "o",
				function()
					require("flash").remote()
				end,
				desc = "Remote Flash",
			},
			{
				"R",
				mode = { "o", "x" },
				function()
					require("flash").treesitter_search()
				end,
				desc = "Treesitter Search",
			},
			{
				"<c-s>",
				mode = { "c" },
				function()
					require("flash").toggle()
				end,
				desc = "Toggle Flash Search",
			},
		},
	},
})

--========================================== plug conf ================================================
require("tokyonight").setup({
	theme = "night",
})
vim.cmd("colorscheme tokyonight-night")

require("project_nvim").setup({})
require("telescope").load_extension("projects")

require("nvim-tree").setup({
	view = {
		width = 20,
	},
})

require("dashboard").setup({
	config = {
		header = {
			[[⠀                    ⢠⠱⢐                      ]],
			[[⠀             ⠀⢂⣀⡁⣅⢌⡤⡥⡦⡦⡢⡱⠬⣤⣅⣌⡀               ]],
			[[⠀            ⣐⣤⢮⣞⢾⢽⣝⢾⢽⢽⣝⠔⡽⡵⣎⡚⠮⣗⡶⣤⡠⠠⠠⠂⡊  ⠀     ]],
			[[⠀         ⡀⣶⣳⣻⣺⢽⣺⣝⢷⢽⢽⣝⣗⣗⢱⢹⣝⣗⡯⣗⢌⢫⢳⡱⡥⡁⢐ ⠀       ]],
			[[⠀       ⢀⣲⢿⢽⣺⣺⣺⢽⣺⣺⢽⣝⣗⣗⢷⢽⡢⡹⣞⠾⣱⡳⣯⣻⢽⡻⣺⢿⡔⠐⠀       ]],
			[[⠀      ⣔⡿⣼⣿⣽⣞⣞⡾⣱⢷⣝⣗⣗⢷⢽⣝⣗⡧⡪⡳⣽⡺⣽⣺⣺⢽⡽⡮⣯⣿⣕        ]],
			[[⠀ ⠀  ⣠⣟⡾⡏⣾⣻⢾⣻⣟⣿⣳⣽⣾⣺⣺⢽⣳⣳⡳⡯⡣⣟⡵⡯⣗⣗⡯⣟⣽⣻⢽⢯⣻⣮⢄      ]],
			[[⠀ ⠀⢡⠺⠉⣔⡿⡑⡷⣽⢸⣳⣳⢽⡲⡵⣳⢽⣺⢽⡺⣪⡯⣳⢹⣳⢯⢯⣗⣗⢯⣗⢷⢽⣺⢵⡇⣟⣿⡠     ]],
			[[⠀     ⣗⡧⡱⣝⣮⡢⡳⢽⢝⣇⠯⣯⣻⣺⢽⢝⢵⢹⢢⣻⡺⣝⣗⢷⢽⢕⡯⣯⣻⣺⡳⡯⡺⣺⣽     ]],
			[[⠀     ⢷⠑⡩⣗⢷⢹⡇⢯⣗⡗⣝⣞⣞⣞⡽⡡⡏⡇⡗⣗⣯⢳⢯⢯⢯⡳⡯⣗⣗⠧⡯⡯⡇⠓⡽⡅    ]],
			[[⠀     ⡫ ⠈⣺⣝⢔⢨⡊⢾⢝⡜⣞⣞⡮⡯⣊⢊⢎⢮⢺⣺⡪⡯⣯⣻⢼⢝⡷⡽⣑⢯⢯⡇ ⠈⢕    ]],
			[[⠀      ⠀ ⣸⣿⣽ ⣻⣆⢻⠪⣳⣳⢯⡫⢬⡪⣏⡎⣞⣗⢇⢿⢵⣫⢮⢯⢯⣻⢐⢯⣟⡆       ]],
			[[⠀      ⢡⣼⣯⣷⣿⣕⢽⣿⣼⡕⡵⡯⣗⢇⣗⢽⢜⡎⣺⡺⡨⡺⣽⡺⣕⢯⣻⣺⠀⣫⢾⡅       ]],
			[[⠀      ⠘⣿⣽⢿⣾⣻⣟⣿⣽⡯⣺⢽⣳⢱⡧⡏⣯⢪⣸⢕⠡⢣⢳⡻⡜⣝⣞⡞ ⠈⢷⠅       ]],
			[[⠀       ⢸⣿⣟⣷⣿⣻⣽⣯⣿⣪⢟⡎⣾⢯⣫⢾⢕⢇⣗⢯⠇⠐⡹⡕⢕⡷⡃  ⠈⡁       ]],
			[[⠀      ⠀ ⠑⢧⣿⡾⣟⣯⣿⢷⢵⣻⢸⡫⣯⡺⣝⣕⢵⡫⣯⠁ ⠈⡊⢸⠇⠀ ⠀         ]],
			[[⠀          ⠻⠟⠿⠻⠫⡻⡱⠏⡮⣯⡺⣝⣞⢮⢯⢯⠞⣊⠄  ⠈⠊            ]],
			[[⠀               ⠌⢘⢀⢟⣞⢮⣳⡳⡝⠣⣕⡶                  ]],
			[[⠀                                             ]],
		},
		disable_move = true,
		shortcut = {
			{
				desc = "󰚰 Update",
				group = "@property",
				action = "Lazy update",
				key = "u",
			},
			{
				desc = " Mason",
				group = "Number",
				action = "Mason",
				key = "m",
			},
			{
				desc = " Load Sessions",
				group = "DiagnosticHint",
				action = "SessionManager load_last_session",
				key = "l",
			},
		},
	},
})

require("navigator").setup({
	lsp = {
		format_on_save = false,
	},
})

-- luasnip loading friendly-snippets
require("luasnip.loaders.from_vscode").lazy_load()
-- cmp conf
local cmp = require("cmp")
cmp.setup({
	snippet = {
		-- REQUIRED - you must specify a snippet engine
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
		end,
	},
	window = {},
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }),
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "buffer" },
		{ name = "path" },
		{ name = "cmdline" },
		{ name = "nvim_lsp_signature_help" },
		{ name = "luasnip" },
		{ name = "treesitter" },
		{ name = "codeium" },
	}),
})

cmp.setup.filetype("gitcommit", {
	sources = cmp.config.sources({
		{ name = "git" },
	}, {
		{ name = "buffer" },
	}),
})

cmp.setup.cmdline({ "/", "?" }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = "buffer" },
	},
})

cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()
-- Set up lsp config.
-- 配置方法详见 https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
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
	show_current_context = true,
	show_current_context_start = true,
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
	ensure_installed = { "c", "lua", "vim", "query" },
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
