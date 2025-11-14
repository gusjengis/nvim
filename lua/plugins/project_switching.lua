return {
  'coffebar/neovim-project',
  opts = {
    projects = { -- define project roots
      '/etc/nixos/',
      '/etc/nix-modules/',
      '~/AppData/Local/nvim',
      '~/.config/nvim',
      '~/.home-manager/',
      '~/wkspaces/Hundo',
      '~/Documents/Code/*',
      '~/Documents/Code/Mosaic/*',
      '~/Documents/Code/Plinth/*',
      '~/Documents/Obsidian/*',
      '~/AndroidStudioProjects/*',
    },
    picker = {
      type = 'telescope',
      preview = { enabled = true, git_status = true, git_fetch = true, show_hidden = true },
    },
  },
  init = function()
    -- enable saving the state of plugins in the session
    vim.opt.sessionoptions:append 'globals' -- save global variables that start with an uppercase letter and contain at least one lowercase letter.
  end,
  dependencies = {
    { 'nvim-lua/plenary.nvim' },
    -- optional picker
    { 'nvim-telescope/telescope.nvim', tag = '0.1.4' },
    -- optional picker
    { 'ibhagwan/fzf-lua' },
    { 'Shatur/neovim-session-manager' },
  },
  lazy = false,
  priority = 100,
}
