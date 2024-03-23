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

-- auto set background
local hour = tonumber(os.date("%H"))
if hour >= 6 and hour < 18 then
	vim.opt.background = "light"
else
	vim.opt.background = "dark"
end

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
-- 搜索要高亮
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
vim.o.termguicolors = true
vim.opt.termguicolors = true
-- 不可见字符的显示，这里只把空格显示为一个点
vim.opt.list = true
-- vim.opt.listchars:append("space:␣")
vim.opt.listchars:append("eol:↵")
-- vim.opt.listchars:append("tab:▏ ")
vim.opt.clipboard = unamedplus --see :help clipboard
vim.opt.cmdheight = 0
-- 开启 Folding
vim.o.foldcolumn = "1" -- '0' is not bad
vim.o.foldlevel = 999 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true
-- vim.wo.foldmethod = "manual"
--vim.wo.foldexpr = "nvim_treesitter#foldexpr()"
-- font
vim.opt.guifont = { "CaskaydiaCove NF", ":h12" }

-- save session before quit
vim.cmd("autocmd VimLeave * :mksession!" .. vim.fn.stdpath("data") .. "/sessions/latest.vim")

-- ========================================== keybind ====================================
-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- fold hotkey
vim.keymap.set("n", "<leader>z", "za")
-- bind sys clipboard as default
vim.keymap.set("n", "y", '"+y')
vim.keymap.set("v", "y", '"+y')
-- package manager
vim.keymap.set("n", "<leader>pu", ":Lazy update<CR>")
vim.keymap.set("n", "<leader>pm", ":Mason<CR>")
vim.keymap.set("n", "<leader>pl", ":LspInfo<CR>")
vim.keymap.set("n", "<leader>pc", ":CmpStatus<CR>")
-- bufferline 左右切换
vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>")
vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>")
vim.keymap.set("n", "<Leader>bp", ":BufferLinePick<CR>")
vim.keymap.set("n", "<Leader>bc", ":BufferLinePickClose<CR>")
-- search
vim.keymap.set("n", "<Leader>sf", ":Telescope fd hidden=true<CR>")
vim.keymap.set("n", "<Leader>so", ":Telescope oldfiles<CR>")
vim.keymap.set("n", "<leader>sg", ":Telescope live_grep<CR>")
-- toggle
vim.keymap.set("n", "<leader>tf", ":NvimTreeFindFileToggle<CR>")
vim.keymap.set("n", "<leader>tg", ":Telescope<CR>")
vim.keymap.set("n", "<leader>td", ":Dashboard<CR>")
vim.keymap.set("n", "<leader>tc", ":CccPick<CR>")
vim.keymap.set("n", "<leader>tx", ":TroubleToggle<CR>")
vim.keymap.set("n", "<leader>tt", ":ToggleTerm direction=tab<CR>")
vim.keymap.set("n", "<leader>to", "<cmd>AerialToggle!<CR>")
vim.keymap.set("n", "<leader>tm", ":MCvisual<CR>")
-- terminal
vim.keymap.set("t", "<esc>", "<C-\\><C-n>")
-- git
vim.keymap.set("n", "<leader>gj", ":Gitsigns next_hunk<CR>")
vim.keymap.set("n", "<leader>gk", ":Gitsigns prev_hunk<CR>")
vim.keymap.set("n", "<leader>gl", ":Gitsigns blame_line<CR>")
vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>")
vim.keymap.set("n", "<leader>gd", ":DiffviewOpen<CR>")
-- debug
vim.keymap.set(
	"n",
	"<leader>dp",
	"<cmd>lua require'dap'.toggle_breakpoint()<cr>",
	{ noremap = true, silent = true }
)
vim.keymap.set(
	"n",
	"<leader>dP",
	"<cmd>lua require'dap'.set_breakpoint(vim.fn.input '[Condition] > ')<cr>",
	{ noremap = true, silent = true }
)
vim.keymap.set("n", "<leader>dc", "<cmd>lua require'dap'.continue()<cr>")
vim.keymap.set("n", "<leader>dx", "<cmd>lua require'dap'.step_over()<cr>")
vim.keymap.set("n", "<leader>di", "<cmd>lua require'dap'.step_into()<cr>")
vim.keymap.set("n", "<leader>du", "<cmd>lua require'dap'.repl.open()<cr>")
-- vim.keymap.set("n", "<leader>dt", "<cmd>lua require'dapui'.toggle()<cr>", {noremap=true,silent=true})
-- vim.keymap.set("n", "<leader>dx", "<cmd>lua require'dap'.terminate()<cr>", {noremap=true,silent=true})
vim.keymap.set("n", "<Leader>lf", "<cmd>Neoformat<CR>")

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
				background = { -- :h background
					light = "latte",
					dark = "mocha",
				},
				-- transparent_background = true,
				color_overrides = {
					all = {
						rosewater = "#CE5D97",
						flamingo = "#A02F6F",
						pink = "#8B7EC8",
						mauve = "#5E409D",
						red = "#D14D41",
						maroon = "#AF3029",
						peach = "#D0A215",
						yellow = "#AD8301",
						green = "#879A39",
						teal = "#66800B",
						sky = "#3AA99F",
						sapphire = "#24837B",
						blue = "#4385BE",
						lavender = "#205EA6",
					},
					mocha = {
						text = "#FFFCF0",
						subtext1 = "#F2F0E5",
						subtext0 = "#E6E4D9",
						overlay2 = "#DAD8CE",
						overlay1 = "#CECDC3",
						overlay0 = "#B7B5AC",
						surface2 = "#878580",
						surface1 = "#6F6E69",
						surface0 = "#575653",
						base = "#100F0F",
						mantle = "#1C1B1A",
						crust = "#282726",
					},
					latte = {
						text = "#100F0F",
						subtext1 = "#1C1B1A",
						subtext0 = "#282726",
						overlay2 = "#343331",
						overlay1 = "#403E3C",
						overlay0 = "#575653",
						surface2 = "#6F6E69",
						surface1 = "#878580",
						surface0 = "#B7B5AC",
						base = "#FFFCF0",
						mantle = "#F2F0E5",
						crust = "#E6E4D9",
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
		{
			"folke/tokyonight.nvim",
			opts = {
				theme = "night",
				on_colors = function(colors)
					colors.bg = "#fdf6e3"
					colors.bg_dark = "#fdf6e3"
				end,
			},
		},
		-- completion
		{
			"hrsh7th/nvim-cmp",
			event = "InsertEnter",
			dependencies = {
				{
					"L3MON4D3/LuaSnip",
					dependencies = { "rafamadriz/friendly-snippets" },
					opts = { history = true, updateevents = "TextChanged,TextChangedI" },
					config = function()
						require("luasnip.loaders.from_vscode").lazy_load()
					end,
				},
				{
					"Exafunction/codeium.nvim",
					config = function()
						require("codeium").setup({})
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
			event = "BufReadPre",
			dependencies = {
				{ "williamboman/mason-lspconfig.nvim" },
				{
					"nvimdev/lspsaga.nvim",
					config = function()
						require("lspsaga").setup({})
					end,
					dependencies = {
						"nvim-treesitter/nvim-treesitter",
						"nvim-tree/nvim-web-devicons",
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
		-- UI
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
		{
			"j-hui/fidget.nvim",
			enabled = false,
			event = "BufReadPre",
			config = function()
				require("fidget").setup({})
			end,
		},
		-- treesitter
		{
			"folke/trouble.nvim",
			event = "BufReadPost",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			opts = {},
		},
		{
			"stevearc/aerial.nvim",
			event = "BufReadPost",
			opts = {},
			dependencies = {
				"nvim-treesitter/nvim-treesitter",
				"nvim-tree/nvim-web-devicons",
			},
			config = function()
				require("aerial").setup({
					-- optionally use on_attach to set keymaps when aerial has attached to a buffer
					on_attach = function(bufnr)
						-- Jump forwards/backwards with '{' and '}'
						vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
						vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
					end,
				})
			end,
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
						additional_vim_regex_highlighting = true,
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
			event = "InsertEnter",
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
			dependencies = {
				{ "nvim-lua/plenary.nvim" },
				{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
			},
			cmd = "Telescope",
			config = function()
				local telescope = require("telescope")
				local telescopeConfig = require("telescope.config")
				local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }
				-- table.insert(vimgrep_arguments, "--color=never")
				-- table.insert(vimgrep_arguments, "--no-heading")
				-- table.insert(vimgrep_arguments, "--with-filename")
				-- table.insert(vimgrep_arguments, "--line-number")
				-- table.insert(vimgrep_arguments, "--column")
				-- table.insert(vimgrep_arguments, "--smart-case")
				table.insert(vimgrep_arguments, "--hidden")
				table.insert(vimgrep_arguments, "--glob=!.git/")
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
		{
			"smoka7/multicursors.nvim",
			event = "BufReadPost",
			dependencies = {
				"smoka7/hydra.nvim",
			},
			opts = {},
			cmd = { "MCstart", "MCvisual", "MCclear", "MCpattern", "MCvisualPattern", "MCunderCursor" },
			keys = {
				{
					mode = { "v", "n" },
					"<Leader>m",
					"<cmd>MCstart<cr>",
					desc = "Create a selection for selected text or word under the cursor",
				},
			},
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
		-- user interface
		{
			"nvim-tree/nvim-tree.lua",
			version = "*",
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
			dependencies = "nvim-tree/nvim-web-devicons",
			event = "BufEnter",
			cmd = { "BufferLineCyclePrev", "BufferLineCycleNext", "BufferLinePick" },
			config = function()
				require("bufferline").setup({
					highlights = require("catppuccin.groups.integrations.bufferline").get({
						custom = {
							all = {},
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
						project = {
							enable = true,
							limit = 8,
						},
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
								desc = " Latest Sessions",
								group = "DiagnosticHint",
								action = "lua local sessionpath = vim.fn.stdpath('data') .. '/sessions/latest.vim' vim.cmd('source ' .. sessionpath)",
								key = "l",
							},
						},
					},
				})
				vim.cmd([[hi DashboardHeader guifg=pink]])
			end,
		},
		{
			"akinsho/toggleterm.nvim",
			event = "BufReadPre",
			config = function()
				require("toggleterm").setup()
			end,
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
					vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#D14D41" })
					vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#DA702C" })
					vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#D0A215" })
					vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#879A39" })
					vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#3AA99F" })
					vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#4385BE" })
					vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#8B7EC8" })
				end)

				require("ibl").setup({
					indent = {
						highlight = highlight,
						char = "│",
						tab_char = "│",
					},
					exclude = {
						filetypes = { "dashboard" },
						buftypes = { "dashboard" },
					},
				})
			end,
		},
		{ "NvChad/nvim-colorizer.lua", config = true, event = "BufReadPre" },
		{ "RRethy/vim-illuminate", event = "BufReadPost" },
		{ "petertriho/nvim-scrollbar", config = true, event = "BufReadPost" },
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
			"LunarVim/bigfile.nvim",
			event = "BufReadPre",
		},
		{
			"folke/which-key.nvim",
			keys = { "<leader>", '"', "'", "`", "c", "v", "g", "<C-w>" },
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
vim.cmd("colorscheme catppuccin")
--vim.cmd("colorscheme tokyonight-night")
