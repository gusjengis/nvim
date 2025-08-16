vim.g.mapleader = ' ' -- set leader key
vim.g.maplocalleader = ' ' -- set leader key
vim.g.have_nerd_font = true
vim.o.number = true -- enable line numbers
vim.o.relativenumber = true -- enable relative line numbers
vim.o.cursorline = false -- Show which line your cursor is on
vim.o.mouse = 'a' -- enable mouse usage
vim.o.showmode = false --hide mode, already in status line
vim.o.breakindent = true -- Enable break indent
vim.o.undofile = true -- Save undo history
vim.o.ignorecase = true -- Case-insenitive searching
vim.o.smartcase = true -- UNLESS \C or one or more capital letters in the search term
vim.o.signcolumn = 'yes' -- Keep signcolumn on by default
vim.o.updatetime = 250 -- Decrease update time
vim.o.timeoutlen = 300 -- Decrease mapped sequence wait time, Displays which-key popup sooner
vim.o.splitright = true -- Configure how new splits should be opened
vim.o.splitbelow = true -- Configure how new splits should be opened
vim.o.list = true -- Sets how neovim will display certain whitespace characters in the editor.
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' } -- Sets how neovim will display certain whitespace characters in the editor.
vim.o.inccommand = 'split' -- Preview substitutions live, as you type!
vim.o.scrolloff = 10 -- Set minimum number of screen lines to keep above and below the cursor.
vim.o.swapfile = false
vim.o.wrap = false
vim.o.cmdheight = 0
vim.o.laststatus = 3 -- Use global statusline
vim.o.statusline = '' -- Clear statusline content
vim.o.winborder = "rounded"
vim.schedule(function() --sync clipboard with OS
  vim.opt.clipboard = 'unnamedplus' --sync clipboard with OS
end) --sync clipboard with OS

vim.api.nvim_create_autocmd('TextYankPost', { -- Highlight when yanking (copying) text
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter', 'BufWinEnter', 'VimResized', 'ColorScheme' }, {
  callback = function()
    vim.o.statusline = ' '
  end,
})
vim.api.nvim_set_hl(0, 'StatusLine', { bg = 'none', fg = 'none' })
vim.api.nvim_set_hl(0, 'StatusLineNC', { bg = 'none', fg = 'none' })
