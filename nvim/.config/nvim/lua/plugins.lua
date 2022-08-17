return require('packer').startup(function(use)

  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- theme
  use {'dracula/vim', as = 'dracula'}
  use 'rmehri01/onenord.nvim'

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

  -- which-key.nvim
  use {
    "folke/which-key.nvim",
    config = function()
      require("which-key").setup {
        icons = {
          breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
          separator = "※ ", -- symbol used between a key and it's label
          group = "+", -- symbol prepended to a group
        },
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
    end
  }

  -- lspconfig
  use {'neovim/nvim-lspconfig'}
  use { 'williamboman/mason.nvim' }

  ---- 补全插件
  use { 'ms-jpq/coq_nvim', branch = 'coq'}
  use { 'ms-jpq/coq.artifacts', branch = 'artifacts'}
  use { 'ms-jpq/coq.thirdparty', branch = '3p'}

  -- lsp plugins
  -- symbol outline
  use 'simrat39/symbols-outline.nvim'

  -- dashboard
  use {
    'goolord/alpha-nvim',
    config = function ()
      require'alpha'.setup(require'alpha.themes.dashboard'.config)
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
  use 'psliwka/vim-smoothie'

  -- multi cursor
  use 'terryma/vim-multiple-cursors'

  -- same to vscode's sticky scroll
  use 'wellle/context.vim'

  -- extend the original vim object keybind
  use 'wellle/targets.vim'

  -- showing diagnostics
  use {
  "folke/trouble.nvim",
  requires = "kyazdani42/nvim-web-devicons",
  config = function()
    require("trouble").setup {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  end
}
end)
