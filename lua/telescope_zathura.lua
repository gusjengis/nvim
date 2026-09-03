local M = {}

local extensions = { 'pdf', 'epub', 'ps', 'eps', 'djvu', 'djv', 'cbr', 'cbz', 'cb7' }

local function selected_path()
  local entry = require('telescope.actions.state').get_selected_entry()
  local path = entry and require('telescope.from_entry').path(entry, true, false)
  return path and vim.fn.fnamemodify(path, ':p') or nil
end

function M.search()
  if vim.fn.executable 'zathura' ~= 1 or vim.fn.executable 'fd' ~= 1 or vim.fn.executable 'busctl' ~= 1 then
    vim.notify('Zathura search requires zathura, fd, and busctl', vim.log.levels.ERROR)
    return
  end

  local actions = require 'telescope.actions'
  local Previewer = require 'telescope.previewers.previewer'
  local viewer
  local launching = false
  local bus_name
  local active = true
  local keep_viewer = false
  local bus_ready = false
  local opening = false
  local wanted_path
  local displayed_path
  local revision = 0

  local function focus_window(selector)
    if vim.fn.executable 'hyprctl' == 1 then
      vim.system { 'hyprctl', 'dispatch', 'focuswindow', selector }
    end
  end

  local function focus_viewer()
    if viewer then
      focus_window('pid:' .. viewer.pid)
    end
  end

  local sync_document

  local function configure_bus(attempt)
    if not viewer or (not active and not keep_viewer) then
      return
    end

    vim.system({
      'busctl',
      '--user',
      '--',
      'call',
      bus_name,
      '/org/pwmt/zathura',
      'org.pwmt.zathura',
      'ExecuteCommand',
      's',
      'set dbus-raise-window false',
    }, { text = true }, function(result)
      vim.schedule(function()
        if result.code == 0 then
          bus_ready = true
          sync_document()
          if keep_viewer and not active then
            focus_viewer()
          end
        elseif viewer and attempt < 20 then
          vim.defer_fn(function()
            configure_bus(attempt + 1)
          end, 100)
        end
      end)
    end)
  end

  local function start_viewer(path)
    launching = true
    displayed_path = path
    local known_windows = {}
    local clients_result = vim.system({ 'hyprctl', 'clients', '-j' }, { text = true }):wait()
    local clients_ok, clients = pcall(vim.json.decode, clients_result.stdout or '')
    if clients_ok then
      for _, client in ipairs(clients) do
        known_windows[client.address] = true
      end
    end

    local command = 'zathura ' .. vim.fn.shellescape(path)
    local dispatcher = string.format('hl.dsp.exec_cmd(%s, { no_initial_focus = true })', vim.inspect(command))

    vim.system({ 'hyprctl', 'dispatch', dispatcher }, { text = true }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          launching = false
          displayed_path = nil
          if active then
            vim.notify('Could not launch Zathura: ' .. (result.stderr or ''), vim.log.levels.ERROR)
          end
          return
        end

        local function find_viewer(attempt)
          vim.system({ 'hyprctl', 'clients', '-j' }, { text = true }, function(clients_response)
            vim.schedule(function()
              local ok, current_clients = pcall(vim.json.decode, clients_response.stdout or '')
              local client = ok
                  and vim.iter(current_clients):find(function(candidate)
                    return candidate.class == 'org.pwmt.zathura' and not known_windows[candidate.address]
                  end)
                or nil
              if not client and attempt < 100 then
                vim.defer_fn(function()
                  find_viewer(attempt + 1)
                end, 25)
                return
              end

              launching = false
              if not client then
                displayed_path = nil
                if active then
                  vim.notify('Could not find new Zathura window', vim.log.levels.ERROR)
                end
                return
              end
              if not active and not keep_viewer then
                vim.uv.kill(client.pid, 15)
                return
              end

              viewer = { pid = client.pid }
              bus_name = 'org.pwmt.zathura.PID-' .. client.pid
              configure_bus(1)
            end)
          end)
        end

        find_viewer(1)
      end)
    end)
  end

  sync_document = function()
    if (not active and not keep_viewer) or not wanted_path or opening or launching then
      return
    end
    if not viewer then
      start_viewer(wanted_path)
      return
    end
    if not bus_ready or wanted_path == displayed_path then
      return
    end

    local path = wanted_path
    opening = true
    vim.system({
      'busctl',
      '--user',
      '--',
      'call',
      bus_name,
      '/org/pwmt/zathura',
      'org.pwmt.zathura',
      'OpenDocument',
      'ssi',
      path,
      '',
      '0',
    }, { text = true }, function(result)
      vim.schedule(function()
        opening = false
        if result.code == 0 then
          displayed_path = path
        else
          bus_ready = false
          if active then
            vim.notify('Could not preview ' .. path, vim.log.levels.ERROR)
          end
          configure_bus(1)
        end
        if result.code == 0 and wanted_path ~= displayed_path then
          sync_document()
        end
      end)
    end)
  end

  local function schedule_preview(path)
    wanted_path = path
    revision = revision + 1
    local scheduled_revision = revision
    vim.defer_fn(function()
      if active and revision == scheduled_revision then
        sync_document()
      end
    end, 180)
  end

  local previewer = Previewer:new {
    title = 'Zathura sidecar',
    dyn_title = function(entry)
      local path = require('telescope.from_entry').path(entry, true, false)
      return path and vim.fn.fnamemodify(path, ':t') or 'Zathura sidecar'
    end,
    preview_fn = function(_, entry, status)
      local path = require('telescope.from_entry').path(entry, true, false)
      if path then
        schedule_preview(vim.fn.fnamemodify(path, ':p'))
      end

      local bufnr = vim.api.nvim_win_get_buf(status.preview_win)
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.bo[bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'Preview opens in Zathura.',
          '',
          '<CR>  keep and focus Zathura',
          '<Esc> close picker and preview',
        })
        vim.bo[bufnr].modifiable = false
      end
    end,
    teardown = function()
      active = false
      revision = revision + 1
      if viewer and not keep_viewer then
        vim.uv.kill(viewer.pid, 15)
        viewer = nil
      end
    end,
  }

  local find_command = { 'fd', '--type', 'f', '--color', 'never' }
  for _, extension in ipairs(extensions) do
    vim.list_extend(find_command, { '--extension', extension })
  end

  require('telescope.builtin').find_files {
    prompt_title = 'Zathura Documents',
    find_command = find_command,
    previewer = previewer,
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local path = selected_path()
        if not path then
          return
        end

        revision = revision + 1
        wanted_path = path
        keep_viewer = true
        sync_document()
        actions.close(prompt_bufnr)
        vim.defer_fn(focus_viewer, 150)
      end)
      return true
    end,
  }
end

return M
