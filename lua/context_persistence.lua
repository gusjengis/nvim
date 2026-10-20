-- Context-owned, per-editor recovery. No operation writes original project files.
local M = {}
local uv = vim.uv or vim.loop
local bit = require('bit')
local ffi = require('ffi')
ffi.cdef 'int flock(int fd, int operation);'
local state = { busy = false, started = false }
local gear = {}
for byte = 0, 255 do gear[byte] = tonumber(vim.fn.sha256(string.char(byte)):sub(1, 8), 16) end

local function chunks(text)
  local pieces, first, line_start, rolling = {}, 1, 1, 0
  for index = 1, #text do
    rolling = bit.tobit(bit.lshift(rolling, 1) + gear[text:byte(index)])
    local size = index - first + 1
    local line_anchor = false
    if text:byte(index) == 10 then
      line_anchor = tonumber(vim.fn.sha256(text:sub(line_start, index)):sub(1, 4), 16) % 16 == 0
      line_start = index + 1
    end
    if size >= 65536 or (size >= 8192 and (bit.band(rolling, 0x3fff) == 0 or line_anchor)) then
      pieces[#pieces + 1] = text:sub(first, index)
      first, rolling = index + 1, 0
    end
  end
  if first <= #text or #text == 0 then pieces[#pieces + 1] = text:sub(first) end
  return pieces
end

local function absolute(path)
  local normalized = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  return normalized == '/' and '/' or normalized:gsub('/+$', '')
end

local function read_json(path)
  return vim.json.decode(table.concat(vim.fn.readfile(path, 'b'), '\n'))
end

local function read_bytes(path)
  local fd = assert(uv.fs_open(path, 'r', 384))
  local size = assert(uv.fs_fstat(fd)).size
  local bytes = assert(uv.fs_read(fd, size, 0))
  assert(uv.fs_close(fd))
  return bytes
end

local function sync_directory(path)
  local directory = assert(uv.fs_open(path, 'r', 448))
  assert(uv.fs_fsync(directory))
  assert(uv.fs_close(directory))
end

local function mkdir(path)
  local missing, parent = {}, path
  while not uv.fs_stat(parent) do
    missing[#missing + 1] = parent
    parent = vim.fs.dirname(parent)
  end
  vim.fn.mkdir(path, 'p', 448)
  for index = #missing, 1, -1 do sync_directory(vim.fs.dirname(missing[index])) end
end

local function write_bytes(path, bytes)
  local temporary = path .. '.checkpoint-tmp-' .. uv.os_gethostname():gsub('[^%w_-]', '_') .. '-' .. uv.os_getpid()
  local fd = assert(uv.fs_open(temporary, 'w', 384))
  assert(uv.fs_write(fd, bytes, 0))
  assert(uv.fs_fsync(fd))
  assert(uv.fs_close(fd))
  assert(uv.fs_rename(temporary, path))
  sync_directory(vim.fs.dirname(path))
end

local function write_json(path, value)
  if vim.fn.filereadable(path) == 1 and vim.deep_equal(read_json(path), value) then
    return false
  end
  write_bytes(path, vim.json.encode(value))
  return true
end

local function stable(value)
  if type(value) ~= 'table' then return vim.json.encode(value) end
  local pieces = {}
  if vim.islist(value) then
    for _, item in ipairs(value) do pieces[#pieces + 1] = stable(item) end
    return '[' .. table.concat(pieces, ',') .. ']'
  end
  local keys = vim.tbl_keys(value)
  table.sort(keys)
  for _, key in ipairs(keys) do pieces[#pieces + 1] = vim.json.encode(key) .. ':' .. stable(value[key]) end
  return '{' .. table.concat(pieces, ',') .. '}'
end

local function integrity(data)
  local copy = vim.deepcopy(data)
  copy.integrity = nil
  return vim.fn.sha256(stable(copy))
end

local function token()
  local bytes = assert(uv.random(16))
  local hex = bytes:gsub('.', function(c)
    return string.format('%02x', c:byte())
  end)
  return hex:sub(1, 8)
    .. '-'
    .. hex:sub(9, 12)
    .. '-4'
    .. hex:sub(14, 16)
    .. '-'
    .. string.format('%x', 8 + bytes:byte(9) % 4)
    .. hex:sub(18, 20)
    .. '-'
    .. hex:sub(21)
end

local function owner(cwd)
  local dir = cwd
  while dir do
    if vim.fn.filereadable(dir .. '/.context/context.json') == 1 then
      state.owner = dir
      return dir
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
  -- Leaving the directory does not sever the editor's context ownership. A
  -- subsequent explicit change into another context updates this association.
  return state.owner or (vim.env.CONTEXT_DIRECTORY and vim.env.CONTEXT_DIRECTORY ~= '' and absolute(vim.env.CONTEXT_DIRECTORY) or nil)
end

local function relative(path, root)
  if root and path == root then
    return '.'
  end
  local prefix = root and (root == '/' and '/' or root .. '/')
  if prefix and path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
end

local function encode_path(path, root)
  path = absolute(path)
  local rel = relative(path, root)
  if rel then
    return { kind = 'context', path = rel }
  end
  rel = relative(path, absolute(vim.env.HOME))
  if rel then
    return { kind = 'home', path = rel }
  end
  return { kind = 'external', path = path }
end

local function decode_path(value, root)
  assert(type(value) == 'table' and type(value.path) == 'string', 'Invalid path metadata')
  if value.kind == 'external' then
    assert(value.path:sub(1, 1) == '/', 'External path must be absolute')
    return value.path
  end
  local base = value.kind == 'context' and root or value.kind == 'home' and vim.env.HOME
  assert(base, 'Missing root for ' .. tostring(value.kind))
  assert(
    value.path:sub(1, 1) ~= '/' and not value.path:match '^%.%./' and not value.path:match '/%.%./' and value.path ~= '..' and not value.path:match '/%.%.$',
    'Invalid relative path'
  )
  return absolute(base .. '/' .. value.path)
end

local function location()
  local cwd = absolute(vim.fn.getcwd(-1, -1))
  local root = owner(absolute(vim.fn.getcwd()))
  local base = root and (root .. '/.context/state/nvim') or (vim.fn.stdpath 'state' .. '/context-nvim')
  local key = encode_path(cwd, root)
  return { cwd = cwd, root = root, base = base, key = vim.fn.sha256(key.kind .. ':' .. key.path) }
end

local function artifact(directory, name)
  assert(type(name) == 'string' and name:sub(1, 1) ~= '/' and not name:find('..', 1, true), 'Invalid artifact path')
  return directory .. '/' .. name
end

local function capture(loc)
  local result = {
    version = 2,
    manifest = 'editor.json',
    editor_id = state.id,
    cwd = encode_path(loc.cwd, loc.root),
    buffers = {},
    tabs = {},
    artifacts = {},
    contents = vim.empty_dict(),
    contents_encoding = 'base64',
    active_tab = vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()),
  }
  local ids, visible = {}, {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_config(win).relative == '' then
        visible[vim.api.nvim_win_get_buf(win)] = true
      end
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and (visible[buf] or vim.bo[buf].buflisted or vim.bo[buf].modified or vim.api.nvim_buf_get_name(buf) == '') then
      local name = vim.api.nvim_buf_get_name(buf)
      local original
      if vim.b[buf].context_recovery then
        -- Re-encode association when :cd changes ownership to another context.
        local file = vim.b[buf].context_original_file
        if file and file ~= '[unnamed]' then
          original = encode_path(file, loc.root)
        end
      else
        original = name ~= '' and encode_path(name, loc.root) or nil
      end
      local entry = {
        id = #result.buffers + 1,
        original = original,
        filetype = vim.bo[buf].filetype,
        fileencoding = vim.bo[buf].fileencoding,
        fileformat = vim.bo[buf].fileformat,
        endofline = vim.bo[buf].endofline,
        bomb = vim.bo[buf].bomb,
        modified = vim.bo[buf].modified,
        buftype = vim.bo[buf].buftype,
        listed = vim.bo[buf].buflisted,
        existed = name ~= '' and vim.fn.filereadable(name) == 1,
      }
      -- Existing recovery buffers remain recovery buffers even after :write.
      if entry.modified or name == '' or vim.b[buf].context_recovery or entry.buftype ~= '' then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        entry.recovery = true
        entry.chunks = {}
        local raw = {}
        for index, line in ipairs(lines) do raw[index] = line:gsub('\n', '\0') end
        local text = table.concat(raw, '\n')
        entry.recovery_format = 'nul-lines'
        entry.sha256 = vim.fn.sha256(text)
        -- Content-defined boundaries resynchronize after insertion/deletion,
        -- including long lines. Base64 RPC preserves arbitrary byte boundaries.
        for _, content in ipairs(chunks(text)) do
          local hash = vim.fn.sha256(content)
          local path = 'objects/' .. hash
          entry.chunks[#entry.chunks + 1] = { path = path, sha256 = hash }
          if not result.contents[path] then
            result.contents[path] = vim.base64.encode(content)
            result.artifacts[#result.artifacts + 1] = { path = path, sha256 = hash }
          end
        end
      end
      ids[buf] = entry.id
      result.buffers[#result.buffers + 1] = entry
    end
  end
  local function layout(node)
    if node[1] ~= 'leaf' then
      local children = {}
      for _, child in ipairs(node[2]) do
        children[#children + 1] = layout(child)
      end
      return { node[1], children }
    end
    local win = node[2]
    local tabnr = vim.api.nvim_tabpage_get_number(vim.api.nvim_win_get_tabpage(win))
    return {
      'leaf',
      {
        buffer = assert(ids[vim.api.nvim_win_get_buf(win)]),
        view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
        width = vim.api.nvim_win_get_width(win),
        height = vim.api.nvim_win_get_height(win),
        cwd = encode_path(vim.fn.getcwd(win, tabnr), loc.root),
        local_cwd = vim.fn.haslocaldir(win, tabnr) == 1,
        active = win == vim.api.nvim_tabpage_get_win(vim.api.nvim_win_get_tabpage(win)),
      },
    }
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local nr = vim.api.nvim_tabpage_get_number(tab)
    result.tabs[#result.tabs + 1] = {
      cwd = encode_path(vim.fn.getcwd(-1, nr), loc.root),
      local_cwd = vim.fn.haslocaldir(-1, nr) ~= 0,
      layout = layout(vim.fn.winlayout(nr)),
    }
  end
  return result
end

--- Synchronous RPC API: returns a JSON string, or raises on incomplete capture.
--- All artifact references in editor.json are relative to destination.
function M.snapshot()
  assert(not state.busy, 'Editor checkpoint already in progress')
  assert(not state.restore_error, 'Previous editor restore failed: ' .. tostring(state.restore_error))
  state.busy = true
  local ok, result = xpcall(function()
    return capture(location())
  end, debug.traceback)
  state.busy = false
  if not ok then
    error(result)
  end
  return vim.json.encode(result)
end

function M.checkpoint(destination)
  assert(type(destination) == 'string' and destination:sub(1, 1) == '/', 'Checkpoint destination must be absolute')
  destination = absolute(destination)
  local result = vim.json.decode(M.snapshot())
  local contents = result.contents
  result.contents = nil
  result.contents_encoding = nil
  for path, encoded in pairs(contents) do contents[path] = vim.base64.decode(encoded) end
  local manifest = destination .. '/editor.json'
  local old = vim.fn.filereadable(manifest) == 1 and read_json(manifest) or nil
  if old then
    assert(old.version == 1 or old.version == 2, 'Unsupported editor checkpoint version')
    assert(old.version ~= 2 or (old.integrity and old.publication), 'Incomplete editor publication')
  end
  assert(#vim.fn.glob(destination .. '/editor.sync-conflict*.json', false, true) == 0, 'Divergent editor sync conflict')
  assert(#vim.fn.glob(destination .. '/conflicts/*.json', false, true) == 0, 'Divergent editor checkpoint preserved; resolve conflict')
  if old and old.integrity then assert(old.integrity == integrity(old), 'Editor manifest integrity failure') end
  local logical = old and vim.deepcopy(old) or nil
  if logical then logical.publication = nil; logical.integrity = nil end
  local local_base = vim.fn.stdpath('state') .. '/context-nvim/publications'
  local key = vim.fn.sha256(destination)
  local witness_path = local_base .. '/' .. key .. '.json'
  local pending = local_base .. '/' .. key .. '.pending.json'
  local mirror = local_base .. '/' .. key .. '.objects'
  local witness = vim.fn.filereadable(witness_path) == 1 and read_json(witness_path) or nil
  local transaction = vim.fn.filereadable(pending) == 1 and read_json(pending) or nil
  local candidate = transaction and transaction.manifest
  local old_publication = old and old.publication
  if candidate and (not old_publication or (old_publication.id ~= transaction.base and old_publication.id ~= candidate.publication.id)) then
    local clock = old_publication and old_publication.clock or {}
    for device, count in pairs(candidate.publication.clock) do
      if (clock[device] or 0) < count then witness = candidate; break end
    end
  end
  if witness then
    local clock = old and old.publication and old.publication.clock or {}
    for device, count in pairs(witness.publication.clock) do
      if (clock[device] or 0) < count then
        for _, item in ipairs(witness.artifacts) do
          local cached = mirror .. '/' .. item.sha256
          local bytes = read_bytes(cached)
          assert(vim.fn.sha256(bytes) == item.sha256, 'Divergent local recovery object missing/corrupt')
          local target = artifact(destination, item.path)
          mkdir(vim.fs.dirname(target))
          if vim.fn.filereadable(target) == 0 or vim.fn.sha256(read_bytes(target)) ~= item.sha256 then
            write_bytes(target, bytes)
          end
        end
        mkdir(destination .. '/conflicts')
        write_json(destination .. '/conflicts/' .. witness.publication.id .. '.json', witness)
        error('Divergent editor checkpoint preserved; resolve conflict')
      end
    end
  end
  -- No scratch files, directory creation or chunk writes on an unchanged tick.
  if old then
    for _, item in ipairs(old.artifacts) do
      local path = artifact(destination, item.path)
      local bytes = old.version == 1 and table.concat(vim.fn.readfile(path, 'b'), '\n') or read_bytes(path)
      assert(vim.fn.sha256(bytes) == item.sha256, 'Recovery integrity failure: ' .. item.path)
    end
  end
  if old and vim.deep_equal(logical, result) and vim.fn.filereadable(pending) == 0 then
    return vim.json.encode(old)
  end
  mkdir(local_base)
  local lock = local_base .. '/' .. key .. '.lock'
  local fd = assert(uv.fs_open(lock, 'a', 384))
  -- Kernel-owned nonblocking lock: crashes release it without PID files,
  -- stale-lock cleanup races, helper callbacks or an editor waiting on itself.
  if ffi.C.flock(fd, 6) ~= 0 then -- LOCK_EX | LOCK_NB
    uv.fs_close(fd)
    error('Editor publication busy; retry')
  end
  local ok, err = xpcall(function()
    local now = vim.fn.filereadable(manifest) == 1 and read_json(manifest) or nil
    assert(vim.deep_equal(now, old), 'Editor checkpoint changed during capture; retry')
    local clock = old and old.publication and vim.deepcopy(old.publication.clock) or {}
    local device = uv.os_gethostname()
    clock[device] = (clock[device] or 0) + 1
    result.publication = { id = token(), clock = clock }
    result.integrity = integrity(result)
    mkdir(destination .. '/objects')
    mkdir(mirror)
    local known = transaction and (transaction.paths or transaction) or {}
    local keep = {}
    for _, item in ipairs(result.artifacts) do
      keep[item.path] = true
    end
    if old then
      for _, item in ipairs(old.artifacts) do
        known[item.path] = true
      end
    end
    for path, _ in pairs(contents) do
      known[path] = true
    end
    local function clean_temporary(path)
      for _, scratch in ipairs(vim.fn.glob(path .. '.checkpoint-tmp-' .. uv.os_gethostname():gsub('[^%w_-]', '_') .. '-*', false, true)) do
        vim.fn.delete(scratch)
      end
    end
    clean_temporary(pending)
    clean_temporary(witness_path)
    write_json(pending, { paths = known, base = old_publication and old_publication.id, manifest = result })
    clean_temporary(manifest)
    for path, _ in pairs(known) do
      clean_temporary(artifact(destination, path))
      local hash = path:match('^objects/(%x+)$')
      if hash then clean_temporary(mirror .. '/' .. hash) end
    end
    for path, content in pairs(contents) do
      local target = artifact(destination, path)
      if vim.fn.filereadable(target) == 0 then
        write_bytes(target, content)
      else
        assert(vim.fn.sha256(read_bytes(target)) == vim.fn.sha256(content), 'Recovery integrity failure: ' .. path)
      end
      local cached = mirror .. '/' .. vim.fn.sha256(content)
      if vim.fn.filereadable(cached) == 0 then
        write_bytes(cached, content)
      else
        assert(vim.fn.sha256(read_bytes(cached)) == vim.fn.sha256(content), 'Local recovery integrity failure')
      end
    end
    now = vim.fn.filereadable(manifest) == 1 and read_json(manifest) or nil
    assert(vim.deep_equal(now, old), 'Editor checkpoint changed during publication; pending capture retained')
    assert(#vim.fn.glob(destination .. '/editor.sync-conflict*.json', false, true) == 0, 'Divergent editor sync conflict')
    write_json(manifest, result)
    write_json(witness_path, result)
    -- Delete only known superseded chunks. Unrecognized incoming sync objects stay.
    for path, _ in pairs(known) do
      if not keep[path] then
        vim.fn.delete(artifact(destination, path))
        local hash = path:match('^objects/(%x+)$')
        if hash then vim.fn.delete(mirror .. '/' .. hash) end
      end
    end
    sync_directory(destination .. '/objects')
    sync_directory(mirror)
    vim.fn.delete(pending)
    sync_directory(local_base)
  end, debug.traceback)
  assert(uv.fs_close(fd))
  if not ok then error(err) end
  return vim.json.encode(result)
end

local function save()
  local loc = location()
  local relative_manifest = 'current/' .. loc.key .. '/editor.json'
  local manifest = loc.base .. '/' .. relative_manifest
  M.checkpoint(vim.fs.dirname(manifest))
  mkdir(loc.base .. '/directories')
  local pointer = loc.base .. '/directories/' .. loc.key .. '.json'
  local previous = vim.fn.filereadable(pointer) == 1 and read_json(pointer) or nil
  write_json(pointer, { version = 2, manifest = relative_manifest })
  -- v1 editor generations were exclusively owned by this feature. Keep roots
  -- still referenced by other directory pointers until those directories migrate.
  local referenced = {}
  for _, path in ipairs(vim.fn.glob(loc.base .. '/directories/*.json', false, true)) do
    local data = read_json(path)
    local id = data.manifest:match('^editors/([^/]+)/')
    if id then referenced[id] = true end
  end
  local old_id = previous and previous.manifest:match('^editors/([^/]+)/')
  if old_id and not referenced[old_id] then
    assert(old_id:match('^[%w_-]+$'), 'Invalid legacy editor identity')
    vim.fn.delete(loc.base .. '/editors/' .. old_id, 'rf')
  end
end

M.save = save

local function restore(filename, standalone)
  assert(filename:sub(1, 1) == '/', 'Restore manifest must be absolute')
  local parent = vim.fs.dirname(filename)
  assert(#vim.fn.glob(parent .. '/editor.sync-conflict*.json', false, true) == 0, 'Divergent editor sync conflict')
  assert(#vim.fn.glob(parent .. '/conflicts/*.json', false, true) == 0, 'Divergent editor checkpoint preserved; resolve conflict')
  local data = read_json(filename)
  assert(data.version == 1 or data.version == 2, 'Unsupported editor checkpoint version')
  assert(not standalone or data.version ~= 2 or (data.integrity and data.publication), 'Incomplete editor publication')
  if data.integrity then assert(data.integrity == integrity(data), 'Editor manifest integrity failure') end
  local directory, root = vim.fs.dirname(filename), location().root
  local recovered = {}
  -- Validate all recovery artifacts before changing the current workspace.
  for _, entry in ipairs(data.buffers) do
    if entry.original then
      local original = decode_path(entry.original, root)
      assert(entry.recovery or not entry.existed or vim.fn.filereadable(original) == 1, 'Original file unavailable: ' .. original)
    end
    if entry.recovery then
      local lines
      if data.version == 2 then
        local pieces = {}
        for _, chunk in ipairs(entry.chunks) do
          local content = read_bytes(artifact(directory, chunk.path))
          assert(vim.fn.sha256(content) == chunk.sha256, 'Recovery integrity failure: ' .. chunk.path)
          pieces[#pieces + 1] = content
        end
        lines = vim.split(table.concat(pieces), '\n', { plain = true })
      else
        lines = vim.fn.readfile(artifact(directory, entry.recovery), 'b')
      end
      local text = table.concat(lines, '\n')
      assert(vim.fn.sha256(text) == entry.sha256, 'Recovery integrity failure: ' .. tostring(entry.recovery))
      recovered[entry.id] = lines
    end
  end
  state.busy = true
  local ok, err = xpcall(function()
    vim.cmd 'silent tabonly!'
    vim.cmd 'silent only!'
    vim.cmd('cd ' .. vim.fn.fnameescape(decode_path(data.cwd, root)))
    local buffers = {}
    -- Editable working copies keep :write from changing published artifacts.
    local working = vim.fn.stdpath 'state' .. '/context-nvim/recovery/' .. state.id
    vim.fn.mkdir(working, 'p', 448)
    for _, entry in ipairs(data.buffers) do
      local buf
      if entry.recovery then
        local copy = working .. '/buffer-' .. entry.id .. '.txt'
        write_bytes(copy, table.concat(recovered[entry.id], '\n'))
        buf = vim.fn.bufadd(copy)
        vim.fn.bufload(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, recovered[entry.id])
        vim.b[buf].context_recovery = true
        vim.b[buf].context_original_path = entry.original
        vim.b[buf].context_original_file = entry.original and decode_path(entry.original, root) or '[unnamed]'
      else
        buf = vim.fn.bufadd(decode_path(assert(entry.original), root))
        vim.fn.bufload(buf)
      end
      vim.bo[buf].buflisted = entry.listed
      vim.bo[buf].bufhidden = 'hide'
      vim.bo[buf].filetype = entry.filetype
      vim.bo[buf].fileencoding = entry.fileencoding
      vim.bo[buf].fileformat = entry.fileformat
      vim.bo[buf].endofline = entry.endofline
      vim.bo[buf].bomb = entry.bomb
      vim.bo[buf].modified = entry.modified
      buffers[entry.id] = buf
    end
    local leaves, active = {}, {}
    local function build(node, win, tab_index)
      if node[1] == 'leaf' then
        local leaf = node[2]
        vim.api.nvim_win_set_buf(win, assert(buffers[leaf.buffer]))
        leaves[#leaves + 1] = { win = win, leaf = leaf }
        if leaf.active or not active[tab_index] then
          active[tab_index] = win
        end
        return
      end
      assert(node[1] == 'row' or node[1] == 'col', 'Invalid split layout')
      local windows = { win }
      for i = 2, #node[2] do
        vim.api.nvim_set_current_win(windows[i - 1])
        vim.cmd(node[1] == 'row' and 'rightbelow vsplit' or 'rightbelow split')
        windows[i] = vim.api.nvim_get_current_win()
      end
      for i, child in ipairs(node[2]) do
        build(child, windows[i], tab_index)
      end
    end
    for i, tab in ipairs(data.tabs) do
      if i > 1 then
        vim.cmd 'tabnew'
      end
      if tab.local_cwd then
        vim.cmd('tcd ' .. vim.fn.fnameescape(decode_path(tab.cwd, root)))
      end
      build(tab.layout, vim.api.nvim_get_current_win(), i)
    end
    for _, item in ipairs(leaves) do
      vim.api.nvim_win_call(item.win, function()
        if item.leaf.local_cwd then
          vim.cmd('lcd ' .. vim.fn.fnameescape(decode_path(item.leaf.cwd, root)))
        end
        vim.api.nvim_win_set_width(item.win, item.leaf.width)
        vim.api.nvim_win_set_height(item.win, item.leaf.height)
        vim.fn.winrestview(item.leaf.view)
      end)
    end
    for _, win in pairs(active) do
      vim.api.nvim_set_current_win(win)
    end
    vim.api.nvim_set_current_win(assert(active[data.active_tab]))
  end, debug.traceback)
  state.busy = false
  if not ok then
    error(err)
  end
end

local function report(fn)
  local ok, err = pcall(fn)
  if not ok then
    vim.notify('Context persistence: ' .. tostring(err), vim.log.levels.ERROR)
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
  if vim.fn.argc() == 0 then
    return true
  end
  return vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 and absolute(vim.fn.argv(0)) == absolute(vim.fn.getcwd())
end

local function startup()
  if not safe_start() then
    return
  end
  if vim.env.CONTEXT_EDITOR_RESTORE and vim.env.CONTEXT_EDITOR_RESTORE ~= '' then
    restore(vim.env.CONTEXT_EDITOR_RESTORE)
    return
  end
  local loc = location()
  local pointer = loc.base .. '/directories/' .. loc.key .. '.json'
  assert(#vim.fn.glob(loc.base .. '/directories/' .. loc.key .. '.sync-conflict*.json', false, true) == 0, 'Divergent editor directory pointer')
  if vim.fn.filereadable(pointer) == 1 then
    restore(artifact(loc.base, read_json(pointer).manifest), true)
    return
  end
  -- Legacy files are never renamed, deleted, or saved over. Load only the exact
  -- current directory; no last-session or project fallback is permitted.
  local legacy = vim.fn.stdpath 'data' .. '/neovim-sessions/' .. loc.cwd:gsub(':', '++'):gsub('/', '__')
  if vim.fn.filereadable(legacy) == 1 then
    vim.cmd('silent source ' .. vim.fn.fnameescape(legacy))
    save()
  end
end

local function advertise()
  local socket = vim.v.servername
  if socket == '' then
    assert(vim.env.XDG_RUNTIME_DIR and vim.env.XDG_RUNTIME_DIR ~= '', 'XDG_RUNTIME_DIR required for editor RPC')
    socket = vim.fn.serverstart(vim.env.XDG_RUNTIME_DIR .. '/context-nvim-' .. state.id .. '.sock')
  end
  state.socket = socket
  if vim.env.TMUX and vim.env.TMUX_PANE then
    local tmux_socket = assert(vim.env.TMUX:match '^(.*),%d+,%d+$', 'Invalid TMUX socket environment')
    -- Existing shells may predate context association. Read explicit session
    -- launch metadata too, so starting an editor after cd outside stays owned.
    local metadata = vim.system({ 'tmux', '-S', tmux_socket, 'show-environment', '-t', vim.env.TMUX_PANE, 'CONTEXT_DIRECTORY' }, { text = true }):wait()
    local root = metadata.code == 0 and metadata.stdout:match '^CONTEXT_DIRECTORY=(.-)\n?$'
    if root and (not vim.env.CONTEXT_DIRECTORY or vim.env.CONTEXT_DIRECTORY == '') and vim.fn.filereadable(root .. '/.context/context.json') == 1 then
      state.owner = absolute(root)
    end
    for option, value in pairs { ['@persistence-editor'] = state.id, ['@persistence-editor-socket'] = socket } do
      local result = vim.system({ 'tmux', '-S', tmux_socket, 'set-option', '-p', '-t', vim.env.TMUX_PANE, option, value }, { text = true }):wait()
      assert(result.code == 0, result.stderr)
    end
  end
end

function M.setup()
  if state.started then
    return
  end
  state.id = vim.env.CONTEXT_EDITOR_ID
  if not state.id or state.id == '' then
    state.id = token()
  end
  assert(state.id:match '^[%w_-]+$' and #state.id <= 64, 'Invalid CONTEXT_EDITOR_ID')
  state.started = true
  vim.g.context_editor_id = state.id
  local group = vim.api.nvim_create_augroup('ContextPersistence', { clear = true })
  vim.api.nvim_create_autocmd('StdinReadPre', {
    group = group,
    callback = function()
      state.stdin = true
    end,
  })
  vim.api.nvim_create_autocmd('DirChanged', {
    group = group,
    callback = function()
      if not state.busy then
        state.location = location()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      if state.timer then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
      end
      if not state.busy then
        if report(save) then
          vim.fn.delete(vim.fn.stdpath('state') .. '/context-nvim/recovery/' .. state.id, 'rf')
        end
      end
    end,
  })
  local function boot()
    vim.g.context_persistence_restore_status = 'loading'
    report(advertise)
    local ok, err = pcall(startup)
    if ok then
      vim.g.context_persistence_restore_status = 'ready'
    else
      state.restore_error = tostring(err)
      vim.g.context_persistence_restore_status = 'failed'
      vim.notify('Context persistence: ' .. state.restore_error, vim.log.levels.ERROR)
    end
    state.timer = uv.new_timer()
    state.timer:start(
      30000,
      30000,
      vim.schedule_wrap(function()
        if not state.busy then
          report(save)
        end
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
