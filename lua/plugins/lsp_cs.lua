return {
  {
    'seblyng/roslyn.nvim',
    ft = 'cs',
    opts = {
      -- Completely ignore Unity's .slnx files so roslyn only sees .sln
      ignore_target = function(target)
        return target:match '%.slnx$' ~= nil
      end,
    },
  },
}
