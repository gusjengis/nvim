return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local function statusline_theme()
        local theme_name = vim.g.colors_name or 'auto'
        local ok, theme = pcall(require, 'lualine.themes.' .. theme_name)
        if not ok then
          theme = require 'lualine.themes.auto'
        end

        theme = vim.deepcopy(theme)
        local inactive_bg = theme.inactive and theme.inactive.b and theme.inactive.b.bg

        for _, mode in ipairs { 'normal', 'insert', 'visual', 'replace', 'command', 'terminal' } do
          local color = theme[mode] and theme[mode].a and theme[mode].a.bg
          if theme[mode] and theme[mode].b then
            theme[mode].b.bg = inactive_bg or theme[mode].b.bg
          end
          if theme[mode] and theme[mode].c then
            theme[mode].c.bg = inactive_bg or theme[mode].c.bg
            theme[mode].c.fg = color or theme[mode].c.fg
          end
        end

        return theme
      end

      local function setup_lualine()
        require('lualine').setup {
          options = {
            icons_enabled = true,
            theme = statusline_theme(),
            component_separators = { left = '', right = '' },
            section_separators = { left = '', right = '' },
            disabled_filetypes = {
              statusline = {},
              winbar = {},
            },
            ignore_focus = {},
            always_divide_middle = true,
            always_show_tabline = true,
            globalstatus = false,
            refresh = {
              winbar = 1000,
              refresh_time = 16, -- ~60fps
              events = {
                'WinEnter',
                'BufEnter',
                'BufWritePost',
                'SessionLoadPost',
                'FileChangedShellPost',
                'VimResized',
                'Filetype',
                'CursorMoved',
                'CursorMovedI',
                'ModeChanged',
              },
            },
          },
          sections = {},
          inactive_sections = {},
          tabline = {},
          winbar = {
            lualine_c = { { 'filename', path = 1 } },
            lualine_z = {},
          },
          inactive_winbar = {
            lualine_c = { { 'filename', path = 1 } },
          },
          extensions = {},
        }

        vim.o.laststatus = 0
        vim.o.statusline = ''
      end

      setup_lualine()

      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('custom_lualine_theme', { clear = true }),
        callback = setup_lualine,
      })
    end,
  },
}
