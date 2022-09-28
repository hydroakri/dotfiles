return require('packer').startup(function(use)

    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    -- theme
    use {'dracula/vim', as = 'dracula'}
    use { "catppuccin/nvim", as = "catppuccin" }

    -- telescope
    use 'BurntSushi/ripgrep'
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.0',
        requires = { {'nvim-lua/plenary.nvim'} }
    }

    -- nvim-tree  
    use {
        'kyazdani42/nvim-tree.lua',
        requires = {
            'kyazdani42/nvim-web-devicons', -- for file icons
        },
        tag = 'nightly' -- updated every week
    }

    -- using packer.nvim
    use {'akinsho/bufferline.nvim', tag = "v2.*", requires = 'kyazdani42/nvim-web-devicons'}

    -- lualine.nvim 
    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'kyazdani42/nvim-web-devicons', opt = true }
    }

    -- treesitter
    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }

    -- toggleterm
    use {"akinsho/toggleterm.nvim", tag = 'v2.*', config = function()
        require("toggleterm").setup()
    end}

    -- session manager
    use 'Shatur/neovim-session-manager'

    -- which-key.nvim
    use {
        "folke/which-key.nvim",
        config = function()
            require("which-key").setup {
                icons = {
                    breadcrumb = "»",
                    separator = "※ ",
                    group = "+",
                },
                -- refer to the configuration section below
            }
        end
    }

    -- lspconfig
    use {'neovim/nvim-lspconfig'}
    use { 'williamboman/mason.nvim' }

    -- lspsaga(beautify)
    use({
        "glepnir/lspsaga.nvim",
        branch = "main",
        config = function()
            local saga = require("lspsaga")

            saga.init_lsp_saga({
                -- your configuration
            })
        end,
    })

    -- dap
    use 'mfussenegger/nvim-dap'
    -- 显示运行时的变量值
    use 'theHamsta/nvim-dap-virtual-text'
    use 'rcarriga/nvim-dap-ui'
    use 'nvim-telescope/telescope-dap.nvim'

    ---- 补全插件
    use { 'ms-jpq/coq_nvim', branch = 'coq'}
    use { 'ms-jpq/coq.artifacts', branch = 'artifacts'}
    use { 'ms-jpq/coq.thirdparty', branch = '3p'}

    -- lsp plugins

    -- symbol outline
    use {
        'simrat39/symbols-outline.nvim',
        config = function ()
            require("symbols-outline").setup()
        end
    }

    -- markdown preview
    use({
        "iamcco/markdown-preview.nvim",
        run = function() vim.fn["mkdp#util#install"]() end,
    })
    -------------------improve experience
    -- blank line 
    use "lukas-reineke/indent-blankline.nvim"

    -- smooth scrool
    use {
        "karb94/neoscroll.nvim",
        config = function()
            require("neoscroll").setup{
            }
        end
    }

    -- multi cursor
    use 'terryma/vim-multiple-cursors'

    -- same to vscode's sticky scroll
    use 'wellle/context.vim'

    -- 括号补全
    use 'jiangmiao/auto-pairs'

    -- extend the original vim object keybind
    use 'wellle/targets.vim'

    -- showing diagnostics 显示报错
    use {
        "folke/trouble.nvim",
        requires = "kyazdani42/nvim-web-devicons",
        config = function()
            require("trouble").setup {
                -- or leave it empty to use the default settings
            }
        end
    }
    -- easymotion
    use {
        "ggandor/leap.nvim",
        requires = "tpope/vim-repeat",
        config = function()
            require("leap").set_default_keymaps{
            }
        end
    }
    -- rainbow parentheses
    use {
        "p00f/nvim-ts-rainbow",
        config = function()
            require("nvim-treesitter.configs").setup {
                highlight = {
                    -- ...
                },
                rainbow = {
                    enable = true,
                    extended_mode = true,
                    max_file_lines = nil,
                }
            }
        end
    }

    -- 匹配高亮 
    use "RRethy/vim-illuminate"

    -- hex color
    use {
        "norcalli/nvim-colorizer.lua",
        config = function ()
            require'colorizer'.setup()
        end
    }

end)
