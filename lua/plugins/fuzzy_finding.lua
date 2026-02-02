local function DeleteBuffer(prompt_bufnr)
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

  if vim.bo[buffer_id].modified then
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

return {
  -- Fuzzy Finder (files, lsp, etc)
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },

    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font }, -- Useful for getting pretty icons, but requires a Nerd Font.
  },
  config = function()
    -- [[ Configure Telescope ]]
    require('telescope').setup {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          prompt_position = "bottom", -- put the prompt at the top
        },
        sorting_strategy = "ascending", -- puts results at the top
        mappings = {
          i = {
            ['<c-d>'] = DeleteBuffer,
          },
        },
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
      },
    }

    pcall(require('telescope').load_extension, 'fzf') -- Enable Telescope extensions if they are installed
    pcall(require('telescope').load_extension, 'ui-select') -- Enable Telescope extensions if they are installed

    local builtin = require 'telescope.builtin'
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
    vim.keymap.set('n', '<leader>/', function()
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        layout_config = {
          width = 0.5, -- Larger search popup
          height = 0.5, -- Larger search popup
        },
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    vim.keymap.set('n', '<leader>s/', function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end, { desc = '[S]earch [/] in Open Files' })

    -- Shortcut for searching your Neovim configuration files
    vim.keymap.set('n', '<leader>sn', function()
      builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })
  end,
}
