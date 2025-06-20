-- window navigation with Alt + arrow keys
vim.api.nvim_set_keymap('n', '<A-Left>', '<C-w>h', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<A-Right>', '<C-w>l', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<A-Up>', '<C-w>k', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<A-Down>', '<C-w>j', { noremap = true, silent = true }) -- git

-- file explorer (file switching and manipulation)
vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })

-- project search
vim.api.nvim_set_keymap('n', '<leader>sp', '<Cmd>NeovimProjectDiscover alphabetical_name<CR>', { noremap = true, silent = true, desc = '[S]earch [P]rojects' })

-- hop, takes you where you're looking
vim.api.nvim_set_keymap('n', 'h', '<Cmd>HopWord<CR>', { noremap = true, silent = true })

-- harpoon (file switching)
vim.keymap.set('n', '<leader>a', ':lua require("harpoon"):list():add()<CR>')
vim.keymap.set('n', '<leader>h', ':lua require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())<CR>')

vim.keymap.set('n', '<C-1>', ':lua require("harpoon"):list():select(1)<CR>')
vim.keymap.set('n', '<C-2>', ':lua require("harpoon"):list():select(2)<CR>')
vim.keymap.set('n', '<C-3>', ':lua require("harpoon"):list():select(3)<CR>')
vim.keymap.set('n', '<C-4>', ':lua require("harpoon"):list():select(4)<CR>')
vim.keymap.set('n', '<C-5>', ':lua require("harpoon"):list():select(5)<CR>')
vim.keymap.set('n', '<C-6>', ':lua require("harpoon"):list():select(6)<CR>')
vim.keymap.set('n', '<C-7>', ':lua require("harpoon"):list():select(7)<CR>')
vim.keymap.set('n', '<C-8>', ':lua require("harpoon"):list():select(8)<CR>')
vim.keymap.set('n', '<C-9>', ':lua require("harpoon"):list():select(9)<CR>')
