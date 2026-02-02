return {
  -- Collection of various small independent plugins/modules
  'echasnovski/mini.nvim',
  config = function()
    require('mini.ai').setup { n_lines = 500 }
    require('mini.surround').setup()

    vim.keymap.set('n', 'sa', '<cmd>MiniSurround.add<CR>', { desc = 'Add surrounding' })
    vim.keymap.set('n', 'sd', '<cmd>MiniSurround.delete<CR>', { desc = 'Delete surrounding' })
    vim.keymap.set('n', 'sr', '<cmd>MiniSurround.replace<CR>', { desc = 'Replace surrounding' })
  end,
}
