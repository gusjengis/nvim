return {
  {
    '3rd/diagram.nvim',
    dir = '~/Documents/Code/diagram.nvim/',
    dependencies = {},
    opts = { -- you can just pass {}, defaults below
      events = {
        render_buffer = { 'InsertLeave', 'BufWinEnter', 'TextChanged' },
        clear_buffer = { 'BufLeave' },
      },
      renderer_options = {
        mermaid = {
          background = 'transparent', -- nil | "transparent" | "white" | "#hex"
          theme = nil, -- nil | "default" | "dark" | "forest" | "neutral"
          scale = 1, -- nil | 1 (default) | 2  | 3 | ...
          width = nil, -- nil | 800 | 400 | ...
          height = nil, -- nil | 600 | 300 | ...
        },
        plantuml = {
          charset = nil,
        },
        d2 = {
          theme_id = nil,
          dark_theme_id = nil,
          scale = nil,
          layout = nil,
          sketch = nil,
        },
        gnuplot = {
          size = nil, -- nil | "800,600" | ...
          font = nil, -- nil | "Arial,12" | ...
          theme = nil, -- nil | "light" | "dark" | custom theme string
        },
      },
    },
    init = function()
      require('diagram').setup {
        integrations = {
          require 'diagram.integrations.markdown',
          require 'diagram.integrations.neorg',
        },
        renderer_options = {
          mermaid = {
            theme = 'dark',
          },
          plantuml = {
            charset = 'utf-8',
          },
          d2 = {
            theme_id = 1,
          },
          gnuplot = {
            theme = 'dark',
            size = '800,600',
          },
        },
      }
    end,
  },
}
