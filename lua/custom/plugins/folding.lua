return {
  {
    'kevinhwang91/nvim-ufo',
    dependencies = { 'kevinhwang91/promise-async' }, -- Required dependency
    config = function()
      -- Set up ufo with default options
      require('ufo').setup {
        provider_selector = function(bufnr, filetype, buftype)
          return { 'lsp', 'indent' }
        end,
      }

      -- Folding keybindings
      vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
      vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
    end,
  },
}
