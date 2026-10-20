return {
  'Shatur/neovim-session-manager',
  dependencies = {
    { 'nvim-lua/plenary.nvim' },
    { 'nvim-telescope/telescope.nvim', tag = '0.1.4' },
  },
  lazy = false,
  priority = 100,
  config = function()
    -- Keep legacy sessions available for exact-directory migration only. Portable
    -- JSON and recovery copies, rather than executable mksession files, own saves.
    require('session_manager').setup {
      sessions_dir = vim.fn.stdpath 'data' .. '/neovim-sessions',
      autoload_mode = require('session_manager.config').AutoloadMode.Disabled,
      autosave_last_session = false,
    }
    require('context_persistence').setup()
  end,
}
