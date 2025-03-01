local M = {}

function M.MyKeymaps()
  -- Ctrl + ` from VSCode
  if vim.fn.has 'mac' == 1 then
    -- Mac-specific key bindings
    vim.api.nvim_set_keymap('n', '<M-D-t>', ':lua ToggleTerminal()<CR>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('i', '<M-D-t>', '<Esc>:lua ToggleTerminal()<CR>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('t', '<M-D-t>', '<C-\\><C-n>:lua ToggleTerminal()<CR>', { noremap = true, silent = true })
  else
    vim.api.nvim_set_keymap('n', '<C-A-t>', ':lua ToggleTerminal()<CR>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('i', '<C-A-t>', '<Esc>:lua ToggleTerminal()<CR>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('t', '<C-A-t>', '<C-\\><C-n>:lua ToggleTerminal()<CR>', { noremap = true, silent = true })
  end
  -- Ctrl + / from every other IDE. why tf are we pressing gc and gcc for this?
  vim.api.nvim_set_keymap('i', '<C-_>', '<Esc><Cmd>Commentary<CR>a', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<C-_>', "<Cmd>'<,'>Commentary<CR><Esc>a", { noremap = true, silent = true })

  -- Ctrl + S from every other program ever. Again, why tf do I have to hit Esc + : + w + Enter when I could just hit Ctrl + S? Ctrl + S isn't even used in insert mode, so fucking stupid.
  vim.api.nvim_set_keymap('i', '<C-s>', '<Esc><Cmd>w<CR>a', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', '<C-s>', '<Cmd>w<CR>', { noremap = true, silent = true })

  -- Restoring the normal function of shift in insert mode
  vim.api.nvim_set_keymap('i', '<S-Left>', '<Esc>v', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<S-Right>', '<Right><Esc>v', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<C-S-Left>', '<Esc>vb', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<S-C-Left>', '<Esc>vb', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<C-S-Right>', '<Right><Esc>ve', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<S-C-Right>', '<Right><Esc>ve', { noremap = true, silent = true })

  vim.api.nvim_set_keymap('i', '<S-Up>', '<Esc>v<Up>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<S-Down>', '<Esc>v<Down>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<S-End>', '<Right><Esc>v<End>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('i', '<S-Home>', '<Esc>v<Home>', { noremap = true, silent = true })

  -- Maintianing normal Shift and Ctrl behavior in visual mode
  vim.api.nvim_set_keymap('v', '<C-Left>', 'b', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<S-C-Left>', 'b', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<C-S-Left>', 'b', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<C-Right>', 'e', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<S-C-Right>', 'e', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<C-S-Right>', 'e', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<S-Left>', 'h', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<S-Right>', 'l', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<S-Up>', 'k', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<S-Down>', 'j', { noremap = true, silent = true })

  --git
  vim.api.nvim_set_keymap('n', '<leader>g', '<Cmd>LazyGit<CR>', { noremap = true, silent = true })

  -- project search
  vim.api.nvim_set_keymap('n', '<leader>sp', '<Cmd>NeovimProjectDiscover<CR>', { noremap = true, silent = true, desc = '[S]earch [P]rojects' })
  vim.api.nvim_set_keymap('n', '<leader>tz', '<Cmd>ZenMode<CR>', { noremap = true, silent = true, desc = '[T]oggle [Z]en Mode' })

  --oil
  vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
end

function M.DeleteBuffer(prompt_bufnr)
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local builtin = require 'telescope.builtin'

  local selection = action_state.get_selected_entry()
  if not selection then
    print 'No selection'
    return
  end

  -- Save the current buffer number and selection row
  local buffer_id = selection.bufnr
  local buffer_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer_id), ':t')
  local cursor_row = action_state.get_current_picker(prompt_bufnr):get_selection_row()

  if vim.api.nvim_buf_get_option(buffer_id, 'modified') then
    vim.ui.select({ 'Yes', 'No' }, { prompt = 'File "' .. buffer_name .. '" has unsaved changes. Force delete? (y/n)' }, function(choice)
      if choice == 'Yes' then
        vim.cmd('bd! ' .. buffer_id)
      end
      builtin.buffers()
    end)
  else
    actions.close(prompt_bufnr)
    vim.cmd('bd! ' .. buffer_id)
    builtin.buffers()
  end

  -- Set the cursor back to the saved position
  vim.defer_fn(function()
    local picker = action_state.get_current_picker(vim.api.nvim_get_current_buf())
    picker:set_selection(cursor_row)
  end, 14)
end

function ToggleTerminal() -- Function to toggle terminal or open if none exists
  local current_tab = vim.api.nvim_get_current_tabpage()
  local t_height = math.max(math.floor(vim.o.lines * 0.15), 10)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(current_tab)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')

    -- If a terminal buffer is found, close the window
    if buftype == 'terminal' and vim.api.nvim_get_current_win() == win then
      vim.api.nvim_win_close(win, true)
      return
    end
    if buftype == 'terminal' then
      vim.api.nvim_set_current_win(win)
      vim.cmd 'startinsert'
      return
    end
  end
  -- Iterate through all buffers to find an existing terminal
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'buftype') == 'terminal' then
      -- If a terminal buffer is found, switch to it
      vim.cmd(tostring ' split')
      vim.cmd 'wincmd J'
      vim.api.nvim_win_set_height(vim.api.nvim_get_current_win(), t_height)
      vim.api.nvim_set_current_buf(buf)
      vim.cmd 'startinsert'
      return
    end
  end
  -- If no terminal is found, create a new one in a split
  vim.cmd(tostring(t_height) .. ' split | terminal')
  vim.cmd 'wincmd J'
  vim.api.nvim_win_set_height(vim.api.nvim_get_current_win(), t_height)
  vim.cmd 'startinsert'
end

vim.api.nvim_create_autocmd('TermOpen', {
  pattern = '*',
  callback = function()
    vim.opt_local.scrollback = 10000 -- Set to your preferred number of lines
  end,
})

return M
