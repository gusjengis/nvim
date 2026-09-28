return {
  {
    'supermaven-inc/supermaven-nvim',
    config = function()
      require('supermaven-nvim').setup {}

      local api = require 'supermaven-nvim.api'
      if api then
        api.use_free_version()
      end
    end,
  },
}
