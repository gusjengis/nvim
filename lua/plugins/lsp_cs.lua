return {
  {
    'seblyng/roslyn.nvim',
    ft = 'cs',
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      -- filewatching = 'roslyn',

      targets = {
        {
          name = 'Hundo',
          solution = '/home/gusjengis/wkspaces/Hundo/Hundo.sln',
        },
      },
      -- your configuration comes here; leave empty for default settings
      -- NOTE: You must configure `cmd` in `config.cmd` unless you have installed via mason
    },
  },
}
