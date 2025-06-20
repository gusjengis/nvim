-- command palette
vim.api.nvim_set_keymap('n', '<C-p>', '<Cmd>Telescope commands<CR>', { noremap = true, silent = true })

-- colorscheme search
vim.api.nvim_set_keymap('n', '<leader>sc', '<Cmd>Telescope colorscheme<CR>', { noremap = true, silent = true, desc = '[S]earch [C]olorschemes' })
