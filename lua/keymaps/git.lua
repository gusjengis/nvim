-- lazygit
vim.api.nvim_set_keymap('n', '<leader>g', '<Cmd>LazyGit<CR>', { noremap = true, silent = true })

-- toggle diffview
vim.api.nvim_set_keymap('n', '<leader>td', ':lua ToggleDiffview()<CR>', { noremap = true, silent = true, desc = '[T]oggle [D]iffview' })

function ToggleDiffview()
  -- Check if Diffview is open by looking for a buffer with filetype 'DiffviewFiles'
  local diffview_open = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'filetype') == 'DiffviewFiles' then
      diffview_open = true
      break
    end
  end

  -- Toggle based on current state
  if diffview_open then
    vim.cmd 'DiffviewClose'
  else
    vim.cmd 'DiffviewOpen'
  end
end
