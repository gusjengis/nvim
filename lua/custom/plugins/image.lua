return {
  {
    '3rd/image.nvim',
    dependencies = { 'luarocks.nvim' },
    config = function()
      require('image').setup {
        backend = 'kitty',
        kitty_method = 'normal',
        processor = 'magick_cli',
        max_height_window_percentage = 50,
        hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.svg' },
        integrations = {
          markdown = {
            enabled = true,
            clear_in_insert_mode = false,
            download_remote_images = true,
            only_render_image_at_cursor = false,
            floating_windows = false, -- if true, images will be rendered in floating markdown windows
            filetypes = { 'markdown', 'vimwiki' }, -- markdown extensions (ie. quarto) can go here
          },
          neorg = {
            enabled = true,
            filetypes = { 'norg' },
          },
          typst = {
            enabled = true,
            filetypes = { 'typst' },
          },
          html = {
            enabled = false,
          },
          css = {
            enabled = false,
          },
        },
      }
    end,
  },
}
