return {
  -- Collection of various small independent plugins/modules
  'echasnovski/mini.nvim',
  config = function()
    require('mini.ai').setup { n_lines = 500 } -- Better Around/Inside textobjects
    require('mini.surround').setup() -- Add/delete/replace surroundings (brackets, quotes, etc.)
    --local statusline = require 'mini.statusline' -- Simple and easy statusline.
    --statusline.setup { use_icons = vim.g.have_nerd_font }
    -----@diagnostic disable-next-line: duplicate-set-field
    --statusline.section_location = function()
    --  return '%2l:%-2v'
    --end
  end,
}
