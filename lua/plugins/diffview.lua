local function soften_diff_add_highlights()
  local ok, diff_add = pcall(vim.api.nvim_get_hl, 0, { name = 'DiffAdd', link = false })
  if not ok or vim.tbl_isempty(diff_add) or not diff_add.bg then
    return
  end

  vim.api.nvim_set_hl(0, 'DiffAdd', { bg = diff_add.bg })
  vim.api.nvim_set_hl(0, 'DiffviewDiffAdd', { bg = diff_add.bg })
end

return {
  {
    'sindrets/diffview.nvim',
    opts = {
      enhanced_diff_hl = true,
    },
    config = function(_, opts)
      require('diffview').setup(opts)

      local group = vim.api.nvim_create_augroup('custom_diffview_highlights', { clear = true })
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = soften_diff_add_highlights,
      })

      soften_diff_add_highlights()
    end,
  },
}
