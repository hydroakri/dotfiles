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
-- vim.wo.cursorline = true
-- vim.wo.cursorcolumn = true
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
-- vim.opt.listchars:append("space:⋅")
-- vim.opt.listchars:append("eol:↵")
vim.opt.listchars:append("tab:▏ ")
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
vim.opt.guifont = { "CaskaydiaCove Nerd Font", ":h12" }

-- ========================================== keybind ====================================
-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- package manager
vim.api.nvim_set_keymap("n", "<leader>pu", ":Lazy update<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>pm", ":Mason<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>pl", ":LspInfo<CR>", { noremap = true, silent = true })
-- window
vim.api.nvim_set_keymap("n", "<A-h>", "<C-w>h", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-j>", "<C-w>j", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-k>", "<C-w>k", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-l>", "<C-w>l", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-q>", "<C-w>q", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-v>", "<C-w>v", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-s>", "<C-w>s", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-Up>", ":horizontal resize -2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-Down>", ":horizontal resize +2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-Left>", ":vertical resize -2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-Right>", ":vertical resize +2<CR>", { noremap = true, silent = true })
-- bufferline 左右切换
vim.api.nvim_set_keymap("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Tab>", ":BufferLineCycleNext<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>bp", ":BufferLinePick<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>bc", ":BufferLinePickClose<CR>", { noremap = true, silent = true })
-- Move text up and down
vim.api.nvim_set_keymap("n", "<A-u>", "<Esc>:m .+1<CR>==gi<Esc>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-d>", "<Esc>:m .-2<CR>==gi<Esc>", { noremap = true, silent = true })
-- search
vim.api.nvim_set_keymap("n", "<Leader>sf", ":Telescope fd hidden=true<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>so", ":Telescope oldfiles<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>sg", ":Telescope live_grep<CR>", { noremap = true, silent = true })
-- toggle
vim.api.nvim_set_keymap("n", "<leader>tf", ":NvimTreeFindFileToggle<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>tg", ":Telescope<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>tsl", ":SessionManager load_session<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>tsd", ":SessionManager delete_session<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>td", ":Dashboard<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>tc", ":CccPick<CR>", { noremap = true, silent = true })
-- git
vim.api.nvim_set_keymap("n", "<leader>gj", ":Gitsigns next_hunk<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>gk", ":Gitsigns prev_hunk<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>gl", ":Gitsigns blame_line<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>gd", ":DiffviewOpen<CR>", { noremap = true, silent = true })
-- debug
vim.api.nvim_set_keymap(
	"n",
	"<leader>dp",
	"<cmd>lua require'dap'.toggle_breakpoint()<cr>",
	{ noremap = true, silent = true }
)
vim.api.nvim_set_keymap(
	"n",
	"<leader>dP",
	"<cmd>lua require'dap'.set_breakpoint(vim.fn.input '[Condition] > ')<cr>",
	{ noremap = true, silent = true }
)
vim.api.nvim_set_keymap("n", "<leader>dc", "<cmd>lua require'dap'.continue()<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>dx", "<cmd>lua require'dap'.step_over()<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>di", "<cmd>lua require'dap'.step_into()<cr>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>du", "<cmd>lua require'dap'.repl.open()<cr>", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("n", "<leader>dt", "<cmd>lua require'dapui'.toggle()<cr>", {noremap=true,silent=true})
-- vim.api.nvim_set_keymap("n", "<leader>dx", "<cmd>lua require'dap'.terminate()<cr>", {noremap=true,silent=true})
vim.api.nvim_set_keymap("n", "<Leader>lf", "<cmd>Neoformat<CR>", { noremap = true, silent = true })

require("lazy").setup({
	defaults = {
		lazy = true,
	},
	spec = {
		-- colorscheme
		{
			"catppuccin/nvim",
			name = "catppuccin",
			opts = {
				transparent_background = true,
				color_overrides = {
					all = {
						base = "#191919",
						mantle = "#191919",
					},
				},
				integrations = {
					illuminate = true,
					dashboard = true,
					flash = true,
					gitsigns = true,
					indent_blankline = {
						enabled = true,
						colored_indent_levels = true,
					},
					mason = true,
					noice = true,
					cmp = true,
					dap = {
						enabled = true,
						enable_ui = true, -- enable nvim-dap-ui
					},
					notify = true,
					treesitter_context = true,
					which_key = true,
				},
			},
		},
		{ "sainnhe/everforest" },
		{
			"folke/tokyonight.nvim",
			opts = {
				theme = "night",
				on_colors = function(colors)
					colors.bg = "#191919"
					colors.bg_dark = "#191919"
				end,
			},
		},
		-- completion
		{
			"hrsh7th/nvim-cmp",
			event = "InsertEnter",
			dependencies = {
				{
					"jcdickinson/codeium.nvim",
					config = function()
						require("codeium").setup({})
					end,
				},
				{
					"L3MON4D3/LuaSnip",
					dependencies = { "rafamadriz/friendly-snippets" },
					opts = { history = true, updateevents = "TextChanged,TextChangedI" },
					config = function()
						require("luasnip.loaders.from_vscode").lazy_load()
					end,
				},
				{
					"hrsh7th/cmp-nvim-lsp",
					"hrsh7th/cmp-buffer",
					"hrsh7th/cmp-path",
					"hrsh7th/cmp-cmdline",
					"hrsh7th/cmp-nvim-lsp-signature-help",
					"ray-x/cmp-treesitter",
					"saadparwaiz1/cmp_luasnip",
				},
			},
			config = function()
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
			end,
		},
		-- lsp
		{
			"neovim/nvim-lspconfig",
			event = "InsertEnter",
			dependencies = {
				{ "williamboman/mason-lspconfig.nvim" },
				{
					"ray-x/navigator.lua",
					dependencies = {
						{ "ray-x/guihua.lua", build = "cd lua/fzy && make" },
					},
					event = "InsertEnter",
					opts = {
						lsp = {
							format_on_save = false,
						},
					},
				},
			},
			config = function()
				local capabilities = require("cmp_nvim_lsp").default_capabilities()
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
			end,
		},
		{
			"williamboman/mason.nvim",
			cmd = "Mason",
			config = function()
				require("mason").setup()
			end,
		},
		{
			"folke/noice.nvim",
			event = "BufReadPre",
			enabled = false,
			opts = {
				lsp = {
					hover = {
						enabled = false,
					},
				},
			},
			dependencies = {
				"MunifTanjim/nui.nvim",
			},
		},
		-- treesitter
		{
			"folke/trouble.nvim",
			event = "BufReadPost",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			opts = {},
		},
		{
			"nvim-treesitter/nvim-treesitter",
			build = ":TSUpdate",
			cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
			dependencies = {
				{ "nvim-treesitter/nvim-treesitter-context", config = true },
			},
			config = function()
				require("nvim-treesitter.configs").setup({
					ensure_installed = {
						"c",
						"lua",
						"vim",
						"query",
						"bash",
						"python",
						"cpp",
						"json",
						"dockerfile",
						"cmake",
						"make",
						"comment",
						"diff",
						"html",
						"http",
						"css",
						"scss",
						"yaml",
						"toml",
					},
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
			end,
		},
		-- format
		{ "sbdchd/neoformat", cmd = "Neoformat" },
		-- refactor
		{
			"ThePrimeagen/refactoring.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
				"nvim-treesitter/nvim-treesitter",
			},
			config = function()
				require("refactoring").setup()
			end,
		},
		-- debug
		{
			"mfussenegger/nvim-dap",
			config = function()
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
			end,
		},
		-- coderunner
		{ "michaelb/sniprun", build = "sh ./install.sh", cmd = "SnipRun" },
		-- git
		{ "sindrets/diffview.nvim", cmd = "DiffviewOpen" },
		{ "lewis6991/gitsigns.nvim", config = true, event = "BufReadPre" },
		-- tools
		{
			"nvim-telescope/telescope.nvim",
			version = "0.1.4",
			dependencies = {
				{ "nvim-lua/plenary.nvim" },
				{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
			},
			cmd = "Telescope",
			config = function()
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
			end,
		},
		{ "mg979/vim-visual-multi", version = "*", event = "InsertEnter" },
		{
			"Shatur/neovim-session-manager",
			dependencies = "nvim-lua/plenary.nvim",
			cmd = "SessionManager",
			config = function()
				require("session_manager").setup({})
			end,
		},
		{
			"numToStr/Comment.nvim",
			keys = {
				{ "gcc", mode = "n", desc = "Comment toggle current line" },
				{ "gc", mode = { "n", "o" }, desc = "Comment toggle linewise" },
				{ "gc", mode = "x", desc = "Comment toggle linewise (visual)" },
				{ "gbc", mode = "n", desc = "Comment toggle current block" },
				{ "gb", mode = { "n", "o" }, desc = "Comment toggle blockwise" },
				{ "gb", mode = "x", desc = "Comment toggle blockwise (visual)" },
			},
			config = function()
				require("Comment").setup()
			end,
		},
		{ "windwp/nvim-autopairs", config = true, event = "BufReadPost" },
		{ "uga-rosa/ccc.nvim", cmd = "CccPick" },
		{ "lambdalisue/suda.vim", cmd = "SudaWrite" },
		-- user interface
		{
			"nvim-tree/nvim-tree.lua",
			version = "nightly",
			dependencies = "nvim-tree/nvim-web-devicons",
			cmd = { "NvimTreeFindFileToggle", "NvimTreeFocus" },
			config = function()
				require("nvim-tree").setup({
					view = {
						width = 20,
					},
				})
			end,
		},
		{
			"akinsho/bufferline.nvim",
			version = "v3.*",
			dependencies = "nvim-tree/nvim-web-devicons",
			event = "BufReadPre",
			cmd = { "BufferLineCyclePrev", "BufferLineCycleNext", "BufferLinePick" },
			config = function()
				require("bufferline").setup({
					highlights = require("catppuccin.groups.integrations.bufferline").get({
						custom = {
							all = {
								fill = { bg = "#191919" },
							},
						},
					}),
				})
			end,
			opts = {
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
			},
		},
		{
			"nvim-lualine/lualine.nvim",
			event = "BufReadPre",
			config = function()
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
			end,
		},
		{
			"nvimdev/dashboard-nvim",
			event = "VimEnter",
			config = function()
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
				vim.cmd([[hi DashboardHeader guifg=pink]])
			end,
		},
		{
			"NvChad/nvterm",
			config = function()
				require("nvterm").setup()
			end,
			keys = {
				{
					"<A-t>",
					mode = { "n", "t" },
					function()
						require("nvterm.terminal").toggle("horizontal")
					end,
				},
				{
					"<A-f>",
					mode = { "n", "t" },
					function()
						require("nvterm.terminal").toggle("float")
					end,
				},
			},
		},
		{
			"lukas-reineke/indent-blankline.nvim",
			main = "ibl",
			event = "BufReadPre",
			opts = {},
			config = function()
				local highlight = {
					"RainbowRed",
					"RainbowYellow",
					"RainbowBlue",
					"RainbowOrange",
					"RainbowGreen",
					"RainbowViolet",
					"RainbowCyan",
				}

				local hooks = require("ibl.hooks")
				hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
					vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
					vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
					vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
					vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
					vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
					vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
					vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
				end)

				require("ibl").setup({ indent = { highlight = highlight } })
			end,
		},
		{ "petertriho/nvim-scrollbar", config = true, event = "BufReadPost" },
		{ "RRethy/vim-illuminate", event = "BufReadPost" },
		{ "NvChad/nvim-colorizer.lua", config = true, event = "BufReadPre" },
		{
			"karb94/neoscroll.nvim",
			keys = { "C-d", "C-u" },
			event = "BufReadPre",
			config = function()
				require("neoscroll").setup()
			end,
		},
		{ "kevinhwang91/nvim-ufo", config = true, dependencies = "kevinhwang91/promise-async", event = "BufReadPost" },
		{
			"anuvyklack/windows.nvim",
			dependencies = { "anuvyklack/middleclass", "anuvyklack/animation.nvim" },
			event = "WinNew",
			config = function()
				vim.o.winwidth = 10
				vim.o.winminwidth = 10
				vim.o.equalalways = false
				require("windows").setup()
			end,
		},
		{
			"LunarVim/bigfile.nvim",
			event = "BufReadPre",
		},
		{
			"folke/which-key.nvim",
			keys = { "<leader>", '"', "'", "`", "c", "v", "g" },
			config = function()
				require("which-key").setup()
			end,
			init = function()
				vim.o.timeout = true
				vim.o.timeoutlen = 0
			end,
		},
		-- language
		{
			"Dhanus3133/LeetBuddy.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
				"nvim-telescope/telescope.nvim",
			},
			config = function()
				require("leetbuddy").setup({
					domain = "cn",
					language = "cpp",
				})
			end,
			keys = {
				{ "<leader>lq", "<cmd>LBQuestions<cr>", desc = "List Questions" },
				{ "<leader>ll", "<cmd>LBQuestion<cr>", desc = "View Question" },
				{ "<leader>lr", "<cmd>LBReset<cr>", desc = "Reset Code" },
				{ "<leader>lt", "<cmd>LBTest<cr>", desc = "Run Code" },
				{ "<leader>ls", "<cmd>LBSubmit<cr>", desc = "Submit Code" },
			},
		},
		{
			"iamcco/markdown-preview.nvim",
			ft = { "markdown", "md" },
			build = function()
				vim.fn["mkdp#util#install"]()
			end,
		},
		-- jump
		{
			"rainbowhxch/accelerated-jk.nvim",
			enabled = false,
			keys = {
				{ "j", mode = "n", "<Plug>(accelerated_jk_gj)", desc = {} },
				{ "k", mode = "n", "<Plug>(accelerated_jk_gk)", desc = {} },
			},
		},
		{
			"folke/flash.nvim",
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
	},
})
-- vim.cmd("colorscheme everforest")
vim.cmd("colorscheme catppuccin-mocha")
--vim.cmd("colorscheme tokyonight-night")
