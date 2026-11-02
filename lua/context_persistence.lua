-- Best-effort file/layout sessions. Never serialize or restore unsaved buffer text.
local M = {}
local uv = vim.uv or vim.loop
local state = { started = false, logged = {} }

local function absolute(path)
  local normalized = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  return normalized == '/' and '/' or normalized:gsub('/+$', '')
end

local function log(operation, err)
  local message = operation .. ': ' .. tostring(err)
  if state.logged[message] then
    return
  end
  state.logged[message] = true
  pcall(function()
    local directory = vim.fn.stdpath 'state' .. '/context-nvim'
    vim.fn.mkdir(directory, 'p', 448)
    vim.fn.writefile({ os.date '%Y-%m-%dT%H:%M:%S' .. ' ' .. message }, directory .. '/sessions.log', 'a')
  end)
end

local function attempt(operation, fn)
  local ok, result = pcall(fn)
  if not ok then
    log(operation, result)
  end
  return ok, result
end

local function location()
  local cwd = absolute(vim.fn.getcwd(-1, -1))
  local root = vim.fs.root(vim.fn.getcwd(), '.context') or state.owner or vim.env.CONTEXT_DIRECTORY
  if root == '' then
    root = nil
  end
  if root then
    state.owner = absolute(root)
  end
  local base = root and (absolute(root) .. '/.context/state/nvim') or (vim.fn.stdpath 'state' .. '/context-nvim')
  return base .. '/sessions/' .. vim.fn.sha256(cwd) .. '.vim'
end

local function session_text()
  local temporary = vim.fn.tempname()
  local options = vim.o.sessionoptions
  -- No blank buffers, terminals, globals, or plugin options. :mksession records
  -- file names/layout only; modified named buffers reopen their on-disk text.
  vim.o.sessionoptions = 'buffers,curdir,folds,tabpages,winsize,skiprtp'
  local ok, result = pcall(function()
    vim.cmd('silent noautocmd mksession! ' .. vim.fn.fnameescape(temporary))
    return table.concat(vim.fn.readfile(temporary, 'b'), '\n')
  end)
  vim.o.sessionoptions = options
  vim.fn.delete(temporary)
  if not ok then
    error(result)
  end
  return result
end

local function write_session(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), 'p', 448)
  local temporary = path .. '.tmp-' .. uv.os_getpid()
  local ok, err = pcall(function()
    assert(vim.fn.writefile(vim.split(text, '\n', { plain = true }), temporary, 'b') == 0, 'Session write failed')
    assert(uv.fs_rename(temporary, path))
  end)
  vim.fn.delete(temporary)
  if not ok then
    error(err)
  end
end

function M.save()
  local path
  local ok = attempt('save', function()
    path = location()
    write_session(path, session_text())
  end)
  -- A failed save must not leave an older session queued for another restore.
  if not ok and path then
    pcall(vim.fn.delete, path)
  end
  return ok
end

function M.snapshot()
  return vim.json.encode {
    version = 3,
    editor_id = state.id,
    session = 'session.vim',
    contents_encoding = 'base64',
    contents = { ['session.vim'] = vim.base64.encode(session_text()) },
  }
end

local function fresh()
  -- Called only during startup. Discard partial restoration without writing files.
  vim.cmd 'silent! noautocmd tabonly!'
  vim.cmd 'silent! noautocmd only!'
  vim.cmd 'silent! noautocmd enew!'
  local current = vim.api.nvim_get_current_buf()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if buffer ~= current then
      pcall(vim.api.nvim_buf_delete, buffer, { force = true })
    end
  end
end

local function restore(path)
  local ok = attempt('restore', function()
    vim.cmd('silent source ' .. vim.fn.fnameescape(path))
  end)
  if not ok then
    vim.fn.delete(path)
    fresh()
  end
  return ok
end

local function safe_start()
  if state.stdin or vim.g.started_with_stdin then
    return false
  end
  for _, arg in ipairs(vim.v.argv) do
    if arg == '-' then
      return false
    end
  end
  return vim.fn.argc() == 0 or (vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1)
end

local function startup()
  if not safe_start() then
    return true
  end
  if vim.env.CONTEXT_EDITOR_FRESH == '1' then
    return true
  end
  if vim.env.CONTEXT_EDITOR_RESTORE and vim.env.CONTEXT_EDITOR_RESTORE ~= '' then
    local manifest = vim.env.CONTEXT_EDITOR_RESTORE
    local ok, data = attempt('manifest', function()
      return vim.json.decode(table.concat(vim.fn.readfile(manifest), '\n'))
    end)
    if not ok or data.version ~= 3 or data.session ~= 'session.vim' then
      vim.fn.delete(manifest)
      return false
    end
    return restore(vim.fs.dirname(manifest) .. '/session.vim')
  end
  local path = location()
  if vim.fn.filereadable(path) == 1 then
    return restore(path)
  end
  return true
end

local function advertise()
  local socket = vim.v.servername
  if socket == '' then
    socket = vim.fn.serverstart(vim.env.XDG_RUNTIME_DIR .. '/context-nvim-' .. state.id .. '.sock')
  end
  if vim.env.TMUX and vim.env.TMUX_PANE then
    local tmux_socket = assert(vim.env.TMUX:match '^(.*),%d+,%d+$', 'Invalid TMUX socket environment')
    local metadata = vim.system({ 'tmux', '-S', tmux_socket, 'show-environment', '-t', vim.env.TMUX_PANE, 'CONTEXT_DIRECTORY' }, { text = true }):wait(1000)
    local root = metadata.code == 0 and metadata.stdout:match '^CONTEXT_DIRECTORY=(.-)\n?$'
    if root and vim.fn.filereadable(root .. '/.context/context.json') == 1 then
      state.owner = absolute(root)
    end
    for option, value in pairs { ['@persistence-editor'] = state.id, ['@persistence-editor-socket'] = socket } do
      local result = vim.system({ 'tmux', '-S', tmux_socket, 'set-option', '-p', '-t', vim.env.TMUX_PANE, option, value }, { text = true }):wait(1000)
      assert(result.code == 0, result.stderr)
    end
  end
end

-- Also supports replacing the old module in an already-running editor.
function M.stop()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  pcall(vim.api.nvim_del_augroup_by_name, 'ContextPersistence')
  state.started = false
end

function M.setup()
  if state.started then
    return
  end
  state.started = true
  state.id = vim.env.CONTEXT_EDITOR_ID
  if not state.id or not state.id:match '^[%w_-]+$' then
    state.id = vim.fn.sha256(tostring(uv.hrtime())):sub(1, 32)
  end
  vim.g.context_editor_id = state.id
  local group = vim.api.nvim_create_augroup('ContextPersistence', { clear = true })
  vim.api.nvim_create_autocmd('StdinReadPre', {
    group = group,
    callback = function()
      state.stdin = true
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.save()
      M.stop()
    end,
  })
  local function boot()
    attempt('advertise', advertise)
    local ok, restored = attempt('startup', startup)
    vim.g.context_persistence_restore_status = ok and restored and 'ready' or 'discarded'
    if not ok then
      fresh()
    end
    state.timer = uv.new_timer()
    state.timer:start(
      30000,
      30000,
      vim.schedule_wrap(function()
        M.save()
      end)
    )
  end
  if vim.v.vim_did_enter == 1 then
    boot()
  else
    vim.api.nvim_create_autocmd('VimEnter', { group = group, once = true, nested = true, callback = boot })
  end
end

return M
