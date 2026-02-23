-- window navigation with Alt + arrow keys
vim.api.nvim_set_keymap('n', '<A-Left>', '<C-w>h', { noremap = true, silent = true, desc = 'Go to the left window' })
vim.api.nvim_set_keymap('n', '<A-Right>', '<C-w>l', { noremap = true, silent = true, desc = 'Go to the right window' })
vim.api.nvim_set_keymap('n', '<A-Up>', '<C-w>k', { noremap = true, silent = true, desc = 'Go to the up window' })
vim.api.nvim_set_keymap('n', '<A-Down>', '<C-w>j', { noremap = true, silent = true, desc = 'Go to the down window' })

-- file explorer (file switching and manipulation)
vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })

-- project search
vim.api.nvim_set_keymap('n', '<leader>sp', '<Cmd>NeovimProjectDiscover alphabetical_name<CR>', { noremap = true, silent = true, desc = '[S]earch [P]rojects' })

-- hop, takes you where you're looking
vim.api.nvim_set_keymap('n', 'H', '<Cmd>HopWordMW<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', 'H', '<Cmd>HopWord<CR>', { noremap = true, silent = true })

-- harpoon (file switching)
vim.keymap.set('n', '<leader>ha', ':lua require("harpoon"):list():add()<CR>', { desc = '[A]dd current buffer to list' })
vim.keymap.set('n', '<leader>he', ':lua require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())<CR>', { desc = '[E]dit buffer list' })

vim.keymap.set('n', '<C-1>', ':lua require("harpoon"):list():select(1)<CR>', { desc = 'Goto buffer [1]' })
vim.keymap.set('n', '<C-2>', ':lua require("harpoon"):list():select(2)<CR>', { desc = 'Goto buffer [2]' })
vim.keymap.set('n', '<C-3>', ':lua require("harpoon"):list():select(3)<CR>', { desc = 'Goto buffer [3]' })
vim.keymap.set('n', '<C-4>', ':lua require("harpoon"):list():select(4)<CR>', { desc = 'Goto buffer [4]' })
vim.keymap.set('n', '<C-5>', ':lua require("harpoon"):list():select(5)<CR>', { desc = 'Goto buffer [5]' })
vim.keymap.set('n', '<C-6>', ':lua require("harpoon"):list():select(6)<CR>', { desc = 'Goto buffer [6]' })
vim.keymap.set('n', '<C-7>', ':lua require("harpoon"):list():select(7)<CR>', { desc = 'Goto buffer [7]' })
vim.keymap.set('n', '<C-8>', ':lua require("harpoon"):list():select(8)<CR>', { desc = 'Goto buffer [8]' })
vim.keymap.set('n', '<C-9>', ':lua require("harpoon"):list():select(9)<CR>', { desc = 'Goto buffer [9]' })

-- Move lines up/down, I've missed this from VSCode
vim.keymap.set('n', '<S-Down>', ':m .+1<CR>==', { noremap = true, desc = 'Move line down' })
vim.keymap.set('n', '<S-Up>', ':m .-2<CR>==', { noremap = true, desc = 'Move line up' })
-- TODO: Figure out why these aren't working for more than one movement
-- vim.keymap.set("v", "<S-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
-- vim.keymap.set("v", "<S-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })

---- Better indenting in visual mode
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left and reselect' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right and reselect' })
