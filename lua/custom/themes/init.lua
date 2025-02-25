return {
  {
    'projekt0n/github-nvim-theme',
    name = 'github-theme',
    priority = 1000,
    init = function()
      vim.cmd.colorscheme 'github_dark_default'
      vim.cmd.hi 'Comment gui=none'
    end,
  },

  {
    'navarasu/onedark.nvim',
    config = function()
      require('onedark').setup {
        style = 'warmer',
      }
    end,
  },

  {
    'folke/tokyonight.nvim',
  },
}
