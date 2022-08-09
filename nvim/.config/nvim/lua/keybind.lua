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

-- Telescope
map("n", "<Leader>ff", ":Telescope fd hidden=true<CR>", opt)
map("n", "<Leader>fh", ":Telescope oldfiles<CR>", opt)
map("n", "<leader>g", ":Telescope live_grep<CR>", opt)

-- nvimTree
map('n', '<Leader>t', ':NvimTreeFindFileToggle<CR>', opt)

-- bufferline 左右切换
-- map("n", "<A-h>", ":BufferLineCyclePrev<CR>", opt)
map("n", "<Tab>", ":BufferLineCycleNext<CR>", opt)
map("n", "<Leader>bc", ":BufferLinePickClose<CR>", opt)

-- toggleterm
map('n', ".", ":ToggleTerm direction=float<CR>", opt)
map('t', "<Esc>", "<C-\\><C-n>", opt)

-- tagbar
map('n', "<Leader>o", ":SymbolsOutline<CR>", opt)

-- trouble
map('n', "<Leader>x", "<cmd>TroubleToggle<CR>", opt)
