local function set_bg_only(group, new_bg)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  hl.bg = new_bg
  vim.api.nvim_set_hl(0, group, hl)
end

local function set_fg_only(group, new_fg)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  hl.fg = new_fg
  vim.api.nvim_set_hl(0, group, hl)
end

local inactive = vim.api.nvim_get_hl(0, { name = 'lualine_b_inactive', link = false })
local inactive_bg = inactive.bg

-- Apply only bg update to all the target groups
for _, group in ipairs {
  'lualine_b_normal',
  'lualine_c_normal',
  'lualine_b_insert',
  'lualine_c_insert',
  'lualine_b_visual',
  'lualine_c_visual',
  'lualine_b_replace',
  'lualine_c_replace',
  'lualine_b_command',
  'lualine_c_command',
  'lualine_b_terminal',
  'lualine_c_terminal',
} do
  set_bg_only(group, inactive_bg)
end

for _, group in ipairs {
  'normal',
  'insert',
  'visual',
  'replace',
  'command',
  'terminal',
} do
  local active_a = vim.api.nvim_get_hl(0, { name = 'lualine_a_' .. group, link = false })
  local active_bg_a = active_a.bg

  set_fg_only('lualine_c_' .. group, active_bg_a)
end
