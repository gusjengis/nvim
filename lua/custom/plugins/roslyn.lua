return {
  {
    'seblyng/roslyn.nvim',
    ft = 'cs',
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      targets = {
        {
          name = '3DT',
          solution = 'C:/Users/antho/Cloud Repositories/3DT/3DT.sln',
        },
      },
      -- your configuration comes here; leave empty for default settings
      -- NOTE: You must configure `cmd` in `config.cmd` unless you have installed via mason
    },
  },
}
