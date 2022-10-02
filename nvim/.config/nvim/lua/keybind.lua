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

-- nvimTree
map('n', 't', ':NvimTreeFindFileToggle<CR>', opt)

-- bufferline 左右切换
-- map("n", "<A-h>", ":BufferLineCyclePrev<CR>", opt)
map("n", "<S-j>", ":BufferLineCyclePrev<CR>", opt)
map("n", "<S-k>", ":BufferLineCycleNext<CR>", opt)
map("n", "<Leader>bc", ":BufferLinePickClose<CR>", opt)

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
