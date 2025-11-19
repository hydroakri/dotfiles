-- bootstrap lazy
local vim = vim
local data = vim.fn.stdpath("data")
if not vim.loop.fs_stat(data .. "/lazy/lazy.nvim") then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--recursive",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		data .. "/lazy/lazy.nvim",
	})
end
vim.opt.rtp:prepend(data .. "/lazy/lazy.nvim")

-- utf8
vim.g.encoding = "UTF-8"
vim.o.fileencoding = "utf-8"
-- jk移动时光标下上方保留8行
vim.o.scrolloff = 4
vim.o.sidescrolloff = 4
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
-- 搜索要高亮
vim.o.hlsearch = true
-- 边输入边搜索
vim.o.incsearch = true
-- 使用增强状态栏后不再需要 vim 的模式提示
vim.o.showmode = false
-- 命令行高为2，提供足够的显示空间
vim.o.cmdheight = 4
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
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.wo.foldmethod = "manual"
-- vim.wo.foldexpr = "nvim_treesitter#foldexpr()"  -- ufo 和 treesitter fold 二选一

-- Autocmds
-- back to the last cursor location
vim.api.nvim_create_autocmd("BufReadPost", {
	group = vim.api.nvim_create_augroup("LastPos", { clear = true }),
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) and vim.bo.filetype ~= "commit" then
			vim.cmd('silent! normal! g`"')
		end
	end,
})
-- nvim-lint
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
	callback = function()
		require("lint").try_lint()
	end,
})

-- KEYBIND
-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- fold hotkey
vim.keymap.set("n", "<leader>z", "za")
-- bind sys clipboard as default
vim.keymap.set("n", "y", '"+y')
vim.keymap.set("v", "y", '"+y')
-- package manager
vim.keymap.set("n", "<leader>pL", ":Lazy<CR>")
vim.keymap.set("n", "<leader>pm", ":Mason<CR>")
vim.keymap.set("n", "<leader>pl", ":LspInfo<CR>")
vim.keymap.set("n", "<leader>pc", ":CmpStatus<CR>")
vim.keymap.set("n", "<leader>pf", ":ConformInfo<CR>")
-- buffer
vim.keymap.set("n", "[b", ":bprevious<CR>")
vim.keymap.set("n", "]b", ":bnext<CR>")

-- LAZY
require("lazy").setup({
	git = { timeout = 600 },
	defaults = {
		lazy = true,
	},
	spec = {
		-- UI/UX
		{
			-- SEARCH TELESCOPE
			{
				{
					"nvim-telescope/telescope.nvim",
					keys = {
						{ mode = "n", "<leader>sf", ":Telescope find_files<cr>", desc = "Find files" },
						{ mode = "n", "<leader>sg", ":Telescope live_grep<cr>", desc = "Live grep" },
						{ mode = "n", "<leader>sb", ":Telescope buffers<cr>", desc = "Find buffer" },
						{ mode = "n", "<leader>sh", ":Telescope help_tags<cr>", desc = "Find help" },
						{ mode = "n", "<leader>ts", ":Telescope<cr>", desc = "Toggle Telescope" },
						-- telescope for lsp
						{ mode = "n", "<leader>sq", ":Telescope quickfix<cr>", desc = "Find quickfix" },
						{ mode = "n", "<leader>ss", ":Telescope lsp_document_symbols<cr>", desc = "Find symbols" },
						{
							mode = "n",
							"<leader>sS",
							":Telescope lsp_workspace_symbols query=",
							desc = "Find workspace symbols",
						},
					},
					dependencies = {
						{ "nvim-lua/plenary.nvim" },
					},
					cmd = "Telescope",
					config = function()
						local vimgrep_arguments = { unpack(require("telescope.config").values.vimgrep_arguments) }
						-- table.insert(vimgrep_arguments, "--color=never")
						-- table.insert(vimgrep_arguments, "--no-heading")
						-- table.insert(vimgrep_arguments, "--with-filename")
						-- table.insert(vimgrep_arguments, "--line-number")
						-- table.insert(vimgrep_arguments, "--column")
						-- table.insert(vimgrep_arguments, "--smart-case")
						table.insert(vimgrep_arguments, "--hidden")
						table.insert(vimgrep_arguments, "--glob=!.git/")
						require("telescope").setup({
							defaults = {
								vimgrep_arguments = vimgrep_arguments,
							},
							pickers = {
								find_files = {
									find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
								},
							},
							extensions = {
								fzf = {
									fuzzy = true, -- false will only do exact matching
									override_generic_sorter = true, -- override the generic sorter
									override_file_sorter = true, -- override the file sorter
									case_mode = "smart_case", -- or "ignore_case" or "respect_case"
								},
							},
						})
					end,
				},
			},

			-- FILE BROWSER
			{
				"nvim-tree/nvim-tree.lua",
				keys = { { mode = "n", "<leader>tf", ":NvimTreeFindFileToggle<CR>", desc = "Toggle NvimTree" } },
				version = "*",
				dependencies = "nvim-tree/nvim-web-devicons",
				cmd = { "NvimTreeFindFileToggle", "NvimTreeFocus" },
				config = function()
					require("nvim-tree").setup({
						view = {
							-- width = 25,
						},
					})
				end,
			},

			-- BUFFERLINE
			{
				"akinsho/bufferline.nvim",
				dependencies = {
					{ "nvim-tree/nvim-web-devicons" },
				},
				keys = {
					{ mode = "n", "<leader>b", ":BufferLinePick<CR>" },
					{ mode = "n", "<leader>B", ":BufferLinePickClose<CR>" },
				},
				event = "BufEnter",
				cmd = { "BufferLineCyclePrev", "BufferLineCycleNext", "BufferLinePick" },
				config = function()
					require("bufferline").setup({
						options = {
							mode = "buffer",
							indicator = {
								icon = "▌",
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
				end,
			},

			-- LUALINE
			{
				"nvim-lualine/lualine.nvim",
				event = "BufReadPre",
				config = function()
					require("lualine").setup({
						options = {
							diagnostics = "nvim_lsp",
							icons_enabled = true,
							theme = "auto",
							component_separators = { left = " ", right = " " },
							section_separators = { left = " ", right = " " },
						},
						winbar = {
							-- lualine_a = { "tabs", "buffers" },
							lualine_a = {},
							lualine_b = {},
							-- lualine_c = { "filetype", "filename", "searchcount" },
							lualine_c = {},
							-- lualine_x = { "searchcount", "encoding", "filesize" },
							lualine_y = {},
							lualine_z = {},
						},
						sections = {
							lualine_a = { "mode" },
							lualine_b = { "progress" },
							lualine_c = { "location", "searchcount" },
							lualine_x = { "diagnostics" },
							lualine_y = { "diff" },
							lualine_z = { "branch" },
						},
					})
				end,
			},

			-- TERMINAL
			{
				"akinsho/toggleterm.nvim",
				keys = {
					{ mode = "n", ".", ":ToggleTerm<CR>", desc = "ToggleTerm" },
					{ mode = "t", "<esc>", "<C-\\><C-n>", desc = "Escape Terminal Mode" },
				},
				event = "BufReadPre",
				config = function()
					require("toggleterm").setup()
				end,
			},

			-- WHICHKEY
			{
				"folke/which-key.nvim",
				event = "VeryLazy",
				keys = { "<leader>", '"', "'", "`", "c", "v", "g", "<C-w>", { mode = "n", "?", ":WhichKey<CR>" } },
				config = function()
					require("which-key").setup()
				end,
				init = function()
					vim.o.timeout = true
					vim.o.timeoutlen = 0
				end,
			},

			-- DASHBOARD
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
							},
						},
					})
					vim.cmd([[hi DashboardHeader guifg=pink]])
				end,
			},
		},

		-- EDIT UTILS
		{
			-- FORMATTOR
			{
				"stevearc/conform.nvim",
				event = { "BufWritePre" },
				cmd = { "ConformInfo" },
				keys = {
					{
						-- Customize or remove this keymap to your liking
						"<leader>f",
						function()
							require("conform").format({ async = true, lsp_fallback = true })
						end,
						mode = "",
						desc = "Format buffer",
					},
				},
				-- Everything in opts will be passed to setup()
				opts = {
					-- Define your formatters
					--c, c++, rust, go, java, python, c#, javascript, jsx, typescript, html, css, kotlin, dart, lua
					formatters_by_ft = {
						c = { "ast-grep" },
						cpp = { "ast-grep" },
						rust = { "ast-grep" },
						go = { "ast-grep" },
						java = { "ast-grep" },
						csharp = { "ast-grep" },
						kotlin = { "ast-grep" },
						dart = { "ast-grep" },
						css = { "prettierd", "ast-grep" },
						flow = { "prettierd" },
						graphql = { "prettierd" },
						html = { "prettierd", "ast-grep" },
						json = { "prettierd" },
						jsx = { "prettierd", "ast-grep" },
						javascript = { "prettierd", "ast-grep" },
						less = { "prettierd" },
						markdown = { "prettierd" },
						scss = { "prettierd" },
						typescript = { "prettierd", "ast-grep" },
						vue = { "prettierd" },
						yaml = { "prettierd" },
						lua = { "stylua", "ast-grep" },
						python = { "ast-grep" },
						bash = { "beautysh" },
						ksh = { "beautysh" },
						csh = { "beautysh" },
						zsh = { "beautysh" },
						sh = { "beautysh" },
						nix = { "nixfmt" },
					},
					-- Set up format-on-save
					format_on_save = { timeout_ms = 500, lsp_fallback = true },
					-- Customize formatters
					formatters = {
						shfmt = {
							prepend_args = { "-i", "2" },
						},
					},
				},
				init = function()
					-- If you want the formatexpr, here is the place to set it
					vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
				end,
			},

			-- LINTER
			{
				"mfussenegger/nvim-lint",
				event = "BufReadPost",
				config = function()
					require("lint").linters_by_ft = {
						lua = { "luacheck" },
						markdown = { "write_good" },
						bash = { "shellcheck" },
						c = { "trivy" },
						cpp = { "trivy" },
						css = { "stylelint" },
						python = { "trivy" },
						javascript = { "trivy" },
						java = { "trivy" },
						rust = { "trivy" },
						go = { "trivy" },
						typescript = { "trivy" },
						tex = { "vale" },
					}
				end,
			},

			-- REFACTOR
			{
				"ThePrimeagen/refactoring.nvim",
				keys = {
					{ mode = "x", "<leader>re", ":Refactor extract<cr>", desc = "Refactor Extract" },
					{ mode = "x", "<leader>rf", ":Refactor extract_to_file<cr>", desc = "Refactor Extract To File" },
					{ mode = "x", "<leader>rv", ":Refactor extract_var<cr>", desc = "Refactor Extract Variable" },
					{
						mode = { "n", "x" },
						"<leader>ri",
						":Refactor inline_var<cr>",
						desc = "Refactor Inline Variable",
					},
					{ mode = "n", "<leader>rI", ":Refactor inline_func<cr>", desc = "Refactor Inline Function" },
					{ mode = "n", "<leader>rb", ":Refactor extract_block<cr>", desc = "Refactor Extract Block" },
					{
						mode = "n",
						"<leader>rbf",
						":Refactor extract_block_to_file<cr>",
						desc = "Refactor Extract Block To File",
					},
				},
				event = "InsertEnter",
				dependencies = {
					"nvim-lua/plenary.nvim",
					"nvim-treesitter/nvim-treesitter",
				},
				config = function()
					require("refactoring").setup()
				end,
			},

			-- JUMP
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

			-- MULTICURSORS
			{
				"jake-stewart/multicursor.nvim",
				event = "BufReadPost",
				branch = "1.0",
				config = function()
					local mc = require("multicursor-nvim")

					mc.setup()

					-- Add cursors above/below the main cursor.
					vim.keymap.set({ "n", "v" }, "<up>", function()
						mc.addCursor("k")
					end)
					vim.keymap.set({ "n", "v" }, "<down>", function()
						mc.addCursor("j")
					end)

					-- Add a cursor and jump to the next word under cursor.
					vim.keymap.set({ "n", "v" }, "<c-n>", function()
						mc.addCursor("*")
					end)

					-- Jump to the next word under cursor but do not add a cursor.
					vim.keymap.set({ "n", "v" }, "<c-s>", function()
						mc.skipCursor("*")
					end)

					-- Rotate the main cursor.
					vim.keymap.set({ "n", "v" }, "<left>", mc.nextCursor)
					vim.keymap.set({ "n", "v" }, "<right>", mc.prevCursor)

					-- Delete the main cursor.
					vim.keymap.set({ "n", "v" }, "<leader>x", mc.deleteCursor)

					-- Add and remove cursors with control + left click.
					vim.keymap.set("n", "<c-leftmouse>", mc.handleMouse)

					vim.keymap.set({ "n", "v" }, "<c-q>", function()
						if mc.cursorsEnabled() then
							-- Stop other cursors from moving.
							-- This allows you to reposition the main cursor.
							mc.disableCursors()
						else
							mc.addCursor()
						end
					end)

					vim.keymap.set("n", "<esc>", function()
						if not mc.cursorsEnabled() then
							mc.enableCursors()
						elseif mc.hasCursors() then
							mc.clearCursors()
						else
							-- Default <esc> handler.
						end
					end)

					-- Align cursor columns.
					vim.keymap.set("n", "<leader>a", mc.alignCursors)

					-- Split visual selections by regex.
					vim.keymap.set("v", "S", mc.splitCursors)

					-- Append/insert for each line of visual selections.
					vim.keymap.set("v", "I", mc.insertVisual)
					vim.keymap.set("v", "A", mc.appendVisual)

					-- match new cursors within visual selections by regex.
					vim.keymap.set("v", "M", mc.matchCursors)

					-- Rotate visual selection contents.
					vim.keymap.set("v", "<leader>t", function()
						mc.transposeCursors(1)
					end)
					vim.keymap.set("v", "<leader>T", function()
						mc.transposeCursors(-1)
					end)

					-- Customize how cursors look.
					vim.api.nvim_set_hl(0, "MultiCursorCursor", { link = "Cursor" })
					vim.api.nvim_set_hl(0, "MultiCursorVisual", { link = "Visual" })
					vim.api.nvim_set_hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
					vim.api.nvim_set_hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
				end,
			},

			-- COMMENT
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

			-- COLOR PICKER
			{
				"uga-rosa/ccc.nvim",
				keys = {
					{ mode = "n", "<leader>cp", ":CccPick<CR>", desc = "Color picker" },
				},
				cmd = "CccPick",
				config = true,
			},
		},

		-- VISUAL UTILS TO ENHANCE EDIT
		{
			-- DISPLAY HEX
			{ "NvChad/nvim-colorizer.lua", config = true, event = "BufReadPre" },

			-- SAME WORD HIGHLIGHT
			{ "RRethy/vim-illuminate", event = "BufReadPost" },

			-- SCROLLBAR
			{ "petertriho/nvim-scrollbar", config = true, event = "BufReadPost" },

			-- GIT DIFF
			{
				{
					"sindrets/diffview.nvim",
					keys = {
						{ mode = "n", "<leader>gd", ":DiffviewOpen<CR>", desc = "Diffview" },
					},
					cmd = "DiffviewOpen",
				},
				{
					"lewis6991/gitsigns.nvim",
					event = "BufReadPre",
					config = function()
						require("gitsigns").setup({
							on_attach = function(bufnr)
								local function map(mode, lhs, rhs, opts)
									opts = vim.tbl_extend("force", { noremap = true, silent = true }, opts or {})
									vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
								end

								-- Navigation
								map(
									"n",
									"]c",
									"&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'",
									{ silent = true, expr = true }
								)
								map(
									"n",
									"[c",
									"&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'",
									{ silent = true, expr = true }
								)

								-- Actions
								map("n", "<leader>hs", ":Gitsigns stage_hunk<CR>")
								map("v", "<leader>hs", ":Gitsigns stage_hunk<CR>")
								map("n", "<leader>hr", ":Gitsigns reset_hunk<CR>")
								map("v", "<leader>hr", ":Gitsigns reset_hunk<CR>")
								map("n", "<leader>hS", "<cmd>Gitsigns stage_buffer<CR>")
								map("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<CR>")
								map("n", "<leader>hR", "<cmd>Gitsigns reset_buffer<CR>")
								map("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<CR>")
								map("n", "<leader>hb", '<cmd>lua require"gitsigns".blame_line{full=true}<CR>')
								map("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<CR>")
								map("n", "<leader>hd", "<cmd>Gitsigns diffthis<CR>")
								map("n", "<leader>hD", '<cmd>lua require"gitsigns".diffthis("~")<CR>')
								map("n", "<leader>td", "<cmd>Gitsigns toggle_deleted<CR>")

								-- Text object
								map("o", "ih", ":<C-U>Gitsigns select_hunk<CR>")
								map("x", "ih", ":<C-U>Gitsigns select_hunk<CR>")
							end,
						})
					end,
				},
			},

			-- INDENT BLANKLINE
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

			-- SMOOTH SCROLL
			{
				"karb94/neoscroll.nvim",
				keys = { "C-d", "C-u" },
				event = "BufReadPre",
				config = function()
					require("neoscroll").setup()
				end,
			},

			-- MODERN FOLD
			{
				"kevinhwang91/nvim-ufo",
				keys = {
					{
						mode = "n",
						"zR",
						function()
							require("ufo").openAllFolds()
						end,
						desc = "ufo-openAllFolds",
					},
					{
						mode = "n",
						"zM",
						function()
							require("ufo").closeAllFolds()
						end,
						desc = "ufo-closeAllFolds",
					},
					{
						mode = "n",
						"zr",
						function()
							require("ufo").openFoldsExceptKinds()
						end,
						desc = "ufo-openFoldExceptKinds",
					},
					{
						mode = "n",
						"zm",
						function()
							require("ufo").closeFoldsWith()
						end,
						desc = "ufo-closeFoldsWith",
					},
					{
						mode = "n",
						"K",
						function()
							local winid = require("ufo").peekFoldedLinesUnderCursor()
							if not winid then
								vim.lsp.buf.hover()
							end
						end,
						desc = "ufo-closeAllFolds",
					},
				},
				dependencies = "kevinhwang91/promise-async",
				event = "BufReadPost",
				config = function()
					local handler = function(virtText, lnum, endLnum, width, truncate)
						local newVirtText = {}
						local suffix = (" 󰁂 %d "):format(endLnum - lnum)
						local sufWidth = vim.fn.strdisplaywidth(suffix)
						local targetWidth = width - sufWidth
						local curWidth = 0
						for _, chunk in ipairs(virtText) do
							local chunkText = chunk[1]
							local chunkWidth = vim.fn.strdisplaywidth(chunkText)
							if targetWidth > curWidth + chunkWidth then
								table.insert(newVirtText, chunk)
							else
								chunkText = truncate(chunkText, targetWidth - curWidth)
								local hlGroup = chunk[2]
								table.insert(newVirtText, { chunkText, hlGroup })
								chunkWidth = vim.fn.strdisplaywidth(chunkText)
								-- str width returned from truncate() may less than 2nd argument, need padding
								if curWidth + chunkWidth < targetWidth then
									suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
								end
								break
							end
							curWidth = curWidth + chunkWidth
						end
						table.insert(newVirtText, { suffix, "MoreMsg" })
						return newVirtText
					end
					require("ufo").setup({
						fold_virt_text_handler = handler,
						-- vim.cmd("hi Folded guibg=bg"),
					})
				end,
			},
		},

		-- ADDITIONS
		{
			-- CODERUNNER
			{ "michaelb/sniprun", build = "sh ./install.sh", cmd = "SnipRun" },
			{
				"Zeioth/markmap.nvim",
				ft = { "md", "markdown" },
				build = "yarn global add markmap-cli",
				cmd = { "MarkmapOpen", "MarkmapSave", "MarkmapWatch", "MarkmapWatchStop" },
				opts = {
					html_output = "/tmp/markmap.html", -- (default) Setting a empty string "" here means: [Current buffer path].html
					hide_toolbar = false, -- (default)
					grace_period = 3600000, -- (default) Stops markmap watch after 60 minutes. Set it to 0 to disable the grace_period.
				},
				config = function(_, opts)
					require("markmap").setup(opts)
				end,
			},

			-- MARKDOWN PREVIEW
			{
				"MeanderingProgrammer/render-markdown.nvim",
				-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
				-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
				-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
				---@module 'render-markdown'
				---@type render.md.UserConfig
				opts = {},
				ft = { "markdown", "md" },
			},

			-- JAVA_lsp_dap_support
			{
				"mfussenegger/nvim-jdtls",
				ft = { "java" },
				dependencies = {
					{ "mfussenegger/nvim-dap" },
					{ "rcarriga/nvim-dap-ui" },
				},
				config = function()
					local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
					local workspace_dir = "/path/to/workspace-root/" .. project_name
					local bundles = {
						vim.fn.glob(
							"~/.local/share/nvim/mason/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
						),
					}
					local extendedClientCapabilities = require("jdtls").extendedClientCapabilities
					extendedClientCapabilities.resolveAdditionalTextEditsSupport = true
					vim.list_extend(
						bundles,
						vim.split(
							vim.fn.glob("~/.local/share/nvim/mason/packages/java-test/extension/server/*.jar", true),
							"\n"
						)
					)
					local config = {
						cmd = {
							-- 💀
							"/usr/lib/jvm/java-17-openjdk/bin/java", -- or '/path/to/java17_or_newer/bin/java'
							-- depends on if `java` is in your $PATH env variable and if it points to the right version.

							"-Declipse.application=org.eclipse.jdt.ls.core.id1",
							"-Dosgi.bundles.defaultStartLevel=4",
							"-Declipse.product=org.eclipse.jdt.ls.core.product",
							"-Dlog.protocol=true",
							"-Dlog.level=ALL",
							"-Xmx1g",
							"--add-modules=ALL-SYSTEM",
							"--add-opens",
							"java.base/java.util=ALL-UNNAMED",
							"--add-opens",
							"java.base/java.lang=ALL-UNNAMED",

							-- 💀
							"-jar",
							data .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.1.6.700.v20231214-2017.jar",
							-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                                       ^^^^^^^^^^^^^^
							-- Must point to the                                                     Change this to
							-- eclipse.jdt.ls installation                                           the actual version

							-- 💀
							"-configuration",
							data .. "/mason/packages/jdtls/config_linux",
							-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^        ^^^^^^
							-- Must point to the                      Change to one of `linux`, `win` or `mac`

							-- 💀
							"-data",
							workspace_dir,
						},

						root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew" }),

						on_attach = function(client, bufnr)
							require("jdtls").setup_dap({ hotcodereplace = "auto" })
							require("jdtls.dap").setup_dap_main_class_configs()
							require("jdtls").add_commands()
						end,

						settings = {
							java = {},
						},

						-- java-debug/vscode-java-test
						init_options = {
							bundles = {
								vim.split(
									vim.fn.glob("~/.local/share/nvim/mason/packages/java-test/extension/server/*.jar"),
									"\n"
								),
								extendedClientCapabilities = extendedClientCapabilities,
							},
						},
					}
					table.insert(
						config.init_options.bundles,
						vim.fn.glob(
							data .. "/mason/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
						)
					)
					require("jdtls").start_or_attach(config)

					local dap = require("dap")
					dap.configurations.java = {
						{
							javaExec = "java",
							request = "launch",
							type = "java",
						},
						{
							type = "java",
							request = "attach",
							name = "Debug (Attach) - Remote",
							hostName = "127.0.0.1",
							port = 5005,
						},
					}
				end,
			},

			-- BIGFILE
			{
				"LunarVim/bigfile.nvim",
				event = "BufReadPre",
			},

			-- LEETCODE
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
		},

		-- COMPLETION CMP
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

		-- SYNATX HL TREESITTER
		{
			-- AUTOPAIR
			{ "windwp/nvim-autopairs", config = true, event = "BufReadPost" },

			-- DIAGNOSTIC
			{
				"folke/trouble.nvim",
				keys = {
					{
						"<leader>xx",
						"<cmd>Trouble diagnostics toggle<cr>",
						desc = "Diagnostics (Trouble)",
					},
					{
						"<leader>xX",
						"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
						desc = "Buffer Diagnostics (Trouble)",
					},
					{
						"<leader>cs",
						"<cmd>Trouble symbols toggle focus=false<cr>",
						desc = "Symbols (Trouble)",
					},
					{
						"<leader>cl",
						"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
						desc = "LSP Definitions / references / ... (Trouble)",
					},
					{
						"<leader>xL",
						"<cmd>Trouble loclist toggle<cr>",
						desc = "Location List (Trouble)",
					},
					{
						"<leader>xQ",
						"<cmd>Trouble qflist toggle<cr>",
						desc = "Quickfix List (Trouble)",
					},
				},
				opts = {}, -- for default options, refer to the configuration section for custom setup.
			},

			-- SYMBOL OUTLINE
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
						on_attach = function(bufnr)
							vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
							vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
						end,
					})
				end,
			},

			-- TREESITTER
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
							"nix",
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
						highlight = {
							enable = true,
							additional_vim_regex_highlighting = true,
						},
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
		},

		-- LSP
		{
			"neovim/nvim-lspconfig",
			event = "BufReadPre",
			keys = {
				-- { mode = "n", "<space>e", vim.diagnostic.open_float, desc = "Open diagnostic float" },
				{ mode = "n", "<space>e", ":Telescope diagnostics<CR>", desc = "Open diagnostic float" },
				{ mode = "n", "[d", vim.diagnostic.goto_prev, desc = "Go to previous diagnostic" },
				{ mode = "n", "]d", vim.diagnostic.goto_next, desc = "Go to next diagnostic" },
				-- { mode = "n", "<space>q", vim.diagnostic.setloclist, desc = "Open diagnostic loclist" },
				{ mode = "n", "<space>q", ":Telescope loclist<CR>", desc = "Open diagnostic loclist" },
				{ mode = "n", "gD", vim.lsp.buf.declaration, desc = "Go to declaration" },
				-- { mode = "n", "gd", vim.lsp.buf.definition, desc = "Go to definition" },
				{ mode = "n", "gd", ":Telescope lsp_definitions<CR>", desc = "Go to definition" },
				{ mode = "n", "K", vim.lsp.buf.hover, desc = "Show hover information" },
				-- { mode = "n", "gi", vim.lsp.buf.implementation, desc = "Show implementation" },
				{ mode = "n", "gi", ":Telescope lsp_implementations<CR>", desc = "Show implementation" },
				{ mode = "n", "<C-k>", vim.lsp.buf.signature_help, desc = "Show signature help" },
				{ mode = "n", "<space>wa", vim.lsp.buf.add_workspace_folder, desc = "Add workspace folder" },
				{ mode = "n", "<space>wr", vim.lsp.buf.remove_workspace_folder, desc = "Remove workspace folder" },
				{
					mode = "n",
					"<space>wl",
					function()
						print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
					end,
					desc = "List workspace folders",
				},
				-- { mode = "n", "<space>D", vim.lsp.buf.type_definition, desc = "Type definition" },
				{ mode = "n", "<space>D", ":Telescope lsp_type_definitions<CR>", desc = "Type definition" },
				{ mode = "n", "<space>rn", vim.lsp.buf.rename, desc = "Rename variables" },
				{ mode = { "n", "v" }, "<space>ca", vim.lsp.buf.code_action, desc = "Code action" },
				-- { mode = "n", "gr", vim.lsp.buf.references, desc = "Show references" },
				{ mode = "n", "gr", ":Telescope lsp_references<CR>", desc = "Show references" },
				--[[ {
						mode = "n",
						"<space>f",
						function()
							vim.lsp.buf.format({ async = true })
						end,
					}, ]]
			},
			dependencies = {
				{
					"mason-org/mason-lspconfig.nvim",
					dependencies = { "mason-org/mason.nvim" },
					config = function()
						require("mason-lspconfig").setup({})
					end,
				},

				-- LSP-Enhancement
				{
					{
						"ray-x/navigator.lua",
						enabled = true,
						config = function()
							require("navigator").setup({
								lsp = { format_on_save = false },
								default_mapping = false,
								keymaps = {},
							})
						end,
						dependencies = {
							{ "ray-x/guihua.lua", build = "cd lua/fzy && make" },
							{ "neovim/nvim-lspconfig" },
						},
					},

					-- LSP PACKAGE MANAGER
					{
						"mason-org/mason.nvim",
						cmd = "Mason",
						config = function()
							require("mason").setup({})
						end,
					},
				},
			},
			config = function()
				local ufo_capabilities = vim.lsp.protocol.make_client_capabilities()
				ufo_capabilities.textDocument.foldingRange = {
					dynamicRegistration = false,
					lineFoldingOnly = true,
				}
				local cmp_capabilities = require("cmp_nvim_lsp").default_capabilities()
			end,
		},

		-- THEME
		{
			"catppuccin/nvim",
			name = "catppuccin",
			setup = function()
				-- change theme accroding to system color mode
				local handle = io.popen([[
                THEME=$(gsettings get org.gnome.desktop.interface color-scheme) echo $THEME ]])
				local theme = handle:read("*a")
				handle:close()
				if string.match(theme, "prefer-dark") then
					vim.o.background = "dark"
				else
					vim.o.background = "light"
				end
			end,
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
						subtext1 = "#E6E4D9",
						subtext0 = "#CECDC3",
						overlay2 = "#B7B5AC",
						overlay1 = "#878580",
						overlay0 = "#6F6E69",
						surface2 = "#575653",
						surface1 = "#403E3C",
						surface0 = "#282726",
						base = "#100F0F",
						mantle = "#1C1B1A",
						crust = "#282726",
					},
					latte = {
						text = "#100F0F",
						subtext1 = "#343331",
						subtext0 = "#6F6E69",
						overlay2 = "#878580",
						overlay1 = "#B7B5AC",
						overlay0 = "#CECDC3",
						surface2 = "#DAD8CE",
						surface1 = "#E6E4D9",
						surface0 = "#F2F0E5",
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

		-- DEBUGGER
		{
			-- DAPUI
			{
				"rcarriga/nvim-dap-ui",
				config = function()
					require("dapui").setup()
				end,
				keys = {
					{
						"<leader>tD",
						function()
							require("dapui").toggle()
						end,
						desc = "Toggle DapUI",
					},
				},
				dependencies = {
					{ "mfussenegger/nvim-dap" },
					{ "nvim-neotest/nvim-nio" },
					{
						"folke/neodev.nvim",
						config = function()
							require("neodev").setup({
								library = { plugins = { "nvim-dap-ui" }, types = true },
							})
						end,
						dependencies = { "hrsh7th/nvim-cmp" },
					},
				},
			},
			-- DAP
			{
				"mfussenegger/nvim-dap",
				keys = {
					{
						mode = "n",
						"<F5>",
						function()
							require("dap").continue()
						end,
						desc = "Debug continue",
					},
					{
						mode = "n",
						"<F10>",
						function()
							require("dap").step_over()
						end,
						desc = "Debug step over",
					},
					{
						mode = "n",
						"<F11>",
						function()
							require("dap").step_into()
						end,
						desc = "Debug step into",
					},
					{
						mode = "n",
						"<F12>",
						function()
							require("dap").step_out()
						end,
						desc = "Debug step out",
					},
					{
						mode = "n",
						"<Leader>b",
						function()
							require("dap").toggle_breakpoint()
						end,
						desc = "Debug toggle breakpoint",
					},
					{
						mode = "n",
						"<Leader>B",
						function()
							require("dap").set_breakpoint()
						end,
						desc = "Debug set breakpoint",
					},
					{
						mode = "n",
						"<Leader>lp",
						function()
							require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
						end,
						desc = "Debug set logpoint",
					},
					{
						mode = "n",
						"<Leader>dr",
						function()
							require("dap").repl.open()
						end,
						desc = "Debug open REPL",
					},
					{
						mode = "n",
						"<Leader>dl",
						function()
							require("dap").run_last()
						end,
						desc = "Debug run last",
					},
					{
						mode = { "n", "v" },
						"<Leader>dh",
						function()
							require("dap.ui.widgets").hover()
						end,
						desc = "Debug hover",
					},
					{
						mode = { "n", "v" },
						"<Leader>dp",
						function()
							require("dap.ui.widgets").preview()
						end,
						desc = "Debug preview",
					},
					{
						mode = "n",
						"<Leader>df",
						function()
							local widgets = require("dap.ui.widgets")
							widgets.centered_float(widgets.frames)
						end,
						desc = "Debug frames",
					},
					{
						mode = "n",
						"<Leader>ds",
						function()
							local widgets = require("dap.ui.widgets")
							widgets.centered_float(widgets.scopes)
						end,
						desc = "Debug scopes",
					},
				},
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
					require("dap").adapters.bashdb = {
						type = "executable",
						command = data .. "/mason/packages/bash-debug-adapter/bash-debug-adapter",
						name = "bashdb",
					}
					require("dap").configurations.sh = {
						{
							type = "bashdb",
							request = "launch",
							name = "Launch file",
							showDebugOutput = true,
							pathBashdb = data .. "/mason/packages/bash-debug-adapter/extension/bashdb_dir/bashdb",
							pathBashdbLib = data .. "/mason/packages/bash-debug-adapter/extension/bashdb_dir",
							trace = true,
							file = "${file}",
							program = "${file}",
							cwd = "${workspaceFolder}",
							pathCat = "cat",
							pathBash = "/bin/bash",
							pathMkfifo = "mkfifo",
							pathPkill = "pkill",
							args = {},
							env = {},
							terminalKind = "integrated",
						},
					}
				end,
			},
		},
	},
})
vim.cmd("colorscheme catppuccin")
