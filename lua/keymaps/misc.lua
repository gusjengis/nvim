-- [[ Basic Keymaps ]] (came with kickstart)
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>') -- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' }) -- Exit terminal mode

-- Ctrl + S from every other program ever. Again, why tf do I have to hit Esc + : + w + Enter when I could just hit Ctrl + S? Ctrl + S isn't even used in insert mode, so fucking stupid.
vim.api.nvim_set_keymap('i', '<C-s>', '<Esc><Cmd>w!<CR>a', { noremap = true, silent = true, desc = 'Save file' })
vim.api.nvim_set_keymap('n', '<C-s>', '<Cmd>w!<CR>', { noremap = true, silent = true, desc = 'Save file' })
