-- Project environments come from direnv, not from a global tool install.
--
-- Sessions are usually started by `create-tmux-session`, which runs `nvim .`
-- straight from tmux. That command never goes through an interactive shell, so
-- the direnv shell hook never fires and none of the project's dev-shell tools
-- are on PATH. This module asks direnv for the project environment itself and
-- applies it to the running Neovim, which is what makes `vim.fn.executable`,
-- language servers and conform formatters see the flake's tools.
--
-- Everything here is async: `direnv export` can build a dev shell on first use,
-- and blocking startup on a Nix build is not acceptable.

local M = {}

local loaded = {} -- root -> true, so each project is exported once per session
local subscribers = {}

--- Run `fn` after every successful environment load, and once immediately.
function M.on_load(fn)
  table.insert(subscribers, fn)
  fn()
end

local function announce()
  for _, fn in ipairs(subscribers) do
    local ok, err = pcall(fn)
    if not ok then
      vim.notify('direnv: subscriber failed: ' .. tostring(err), vim.log.levels.WARN)
    end
  end
end

local function apply(env)
  for key, value in pairs(env) do
    -- direnv reports removals as JSON null, which decodes to vim.NIL.
    if value == vim.NIL then
      vim.env[key] = nil
    else
      vim.env[key] = value
    end
  end
end

--- Find the nearest .envrc at or above `dir`.
local function find_root(dir)
  local envrc = vim.fs.find('.envrc', { upward = true, path = dir, type = 'file' })[1]
  return envrc and vim.fs.dirname(envrc) or nil
end

--- Load the direnv environment for `dir` (defaults to the current directory).
function M.load(dir)
  if vim.fn.executable 'direnv' ~= 1 then
    return
  end

  local root = find_root(dir or vim.uv.cwd())
  if not root or loaded[root] then
    return
  end
  loaded[root] = true

  vim.system(
    { 'direnv', 'export', 'json' },
    { cwd = root, text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify('direnv: export failed in ' .. root .. '\n' .. (result.stderr or ''), vim.log.levels.WARN)
        loaded[root] = nil
        return
      end

      -- A blocked .envrc exits 0 with an empty export and a stderr hint.
      if (result.stderr or ''):match 'is blocked' then
        vim.notify('direnv: ' .. root .. ' is blocked, run `direnv allow`', vim.log.levels.WARN)
        loaded[root] = nil
        return
      end

      local payload = vim.trim(result.stdout or '')
      if payload == '' then
        return
      end

      local ok, env = pcall(vim.json.decode, payload)
      if not ok or type(env) ~= 'table' then
        vim.notify('direnv: could not parse export for ' .. root, vim.log.levels.WARN)
        return
      end

      apply(env)
      announce()
    end)
  )
end

function M.setup()
  local group = vim.api.nvim_create_augroup('direnv-env', { clear = true })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      M.load()
    end,
  })

  -- `:cd` into another project, and files opened from outside the start
  -- directory, both pull in that project's environment too.
  vim.api.nvim_create_autocmd('DirChanged', {
    group = group,
    callback = function()
      M.load()
    end,
  })

  vim.api.nvim_create_autocmd('BufReadPost', {
    group = group,
    callback = function(event)
      local name = vim.api.nvim_buf_get_name(event.buf)
      if name ~= '' and not name:match '^%w+://' then
        M.load(vim.fs.dirname(name))
      end
    end,
  })
end

return M
