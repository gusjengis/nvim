-- lazygit
vim.api.nvim_set_keymap('n', '<leader>g', '<Cmd>LazyGit<CR>', { noremap = true, silent = true })

-- toggle diffview
vim.api.nvim_set_keymap('n', '<leader>td', ':lua ToggleDiffview()<CR>', { noremap = true, silent = true, desc = '[T]oggle [D]iffview' })
vim.api.nvim_set_keymap('n', '<leader>th', ':lua ToggleDiffviewHistory()<CR>', { noremap = true, silent = true, desc = '[T]oggle [D]iffview [H]istory' })

-- blame commit diff
vim.api.nvim_set_keymap('n', '<leader>ld', '<Cmd>lua ToggleBlameCommitDiff()<CR>', { noremap = true, silent = true, desc = '[L]ast [D]iff of current line' })

function ToggleBlameCommitDiff()
  local diffview_open = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'DiffviewFiles' then
      diffview_open = true
      break
    end
  end

  if diffview_open then
    vim.cmd 'DiffviewClose'
  else
    local blame_dict = vim.b.gitsigns_blame_line_dict
    if not blame_dict or not blame_dict.sha then
      vim.notify('No blame information available for this line', vim.log.levels.WARN)
      return
    end

    local commit = blame_dict.sha
    local result = vim.fn.systemlist('git rev-parse ' .. commit .. '^')
    local parent = result[1]

    if not parent or parent == '' then
      vim.notify('This is the initial commit - no parent to compare against', vim.log.levels.WARN)
      return
    end

    vim.cmd('DiffviewOpen ' .. parent .. '..' .. commit)
  end
end

function ToggleDiffview()
  -- Check if Diffview is open by looking for a buffer with filetype 'DiffviewFiles'
  local diffview_open = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'DiffviewFiles' then
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

function ToggleDiffviewHistory()
  -- Check if Diffview is open by looking for a buffer with filetype 'DiffviewFiles'
  local diffview_open = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'DiffviewFileHistory' then
      diffview_open = true
      break
    end
  end

  -- Toggle based on current state
  if diffview_open then
    vim.cmd 'DiffviewClose'
  else
    vim.cmd 'DiffviewFileHistory'
  end
end
