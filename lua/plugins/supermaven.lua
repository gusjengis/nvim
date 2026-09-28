return {
  {
    'supermaven-inc/supermaven-nvim',
    build = ':SupermavenUseFree', -- Automatically switches to the free version
    config = function()
      require('supermaven-nvim').setup {}
    end,
  },
}
