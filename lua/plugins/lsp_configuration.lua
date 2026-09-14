-- Language servers are whatever the current environment provides.
--
-- No Mason: Mason downloads unpinned binaries into ~/.local/share/nvim, which
-- is machine-local mutable state and the reason two machines running the same
-- config behaved differently. Servers now come from Nix - a project's flake
-- dev shell via direnv, or the small baseline set in the nvim Nix module - and
-- a server is enabled only when its executable is actually on PATH.
--
-- Adding a language to a project therefore means adding it to that project's
-- devShell, not installing anything here.

-- lspconfig name -> extra settings merged over the upstream definition.
-- Entries without settings still need to be listed: this table is the set of
-- servers we are willing to start.
local servers = {
  arduino_language_server = {},
  bashls = {},
  clangd = {},
  cssls = {},
  gopls = {},
  hyprls = {},
  jsonls = {},
  lua_ls = {
    settings = {
      Lua = { completion = { callSnippet = 'Replace' } },
    },
  },
  marksman = {},
  nil_ls = {},
  pyright = {},
  qmlls = {},
  ruff = {},
  rust_analyzer = {
    settings = {
      ['rust-analyzer'] = {
        checkOnSave = true,
        check = { command = 'clippy', extraArgs = { '--no-deps' } },
        procMacro = { enable = true },
        cargo = { allFeatures = true },
        imports = { granularity = { group = 'module' }, prefix = 'self' },
      },
    },
  },
  taplo = {},
  tinymist = {},
  ts_ls = {},
  wgsl_analyzer = {},
  yamlls = {},
}

local enabled = {}

--- Enable every configured server whose command exists in the current PATH.
--- Runs again whenever direnv brings a project environment in, so a dev shell
--- that appears after startup still gets its servers.
local function enable_available()
  local names = vim.tbl_keys(servers)
  table.sort(names)

  local started = {}
  for _, name in ipairs(names) do
    if not enabled[name] then
      local config = vim.lsp.config[name]
      local cmd = config and config.cmd
      -- Some upstream configs resolve their command at attach time; those are
      -- left to decide for themselves.
      local executable = type(cmd) == 'table' and cmd[1] or nil

      if executable == nil or vim.fn.executable(executable) == 1 then
        enabled[name] = true
        table.insert(started, name)
      end
    end
  end

  if #started > 0 then
    vim.lsp.enable(started)
  end
end

return {
  'neovim/nvim-lspconfig', -- ships the upstream lsp/<server>.lua definitions
  dependencies = {
    { 'j-hui/fidget.nvim', opts = {} },
    'hrsh7th/cmp-nvim-lsp', -- extra capabilities provided by nvim-cmp
  },

  config = function()
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition') -- Jump to the definition of the word under your cursor. This is where a variable was first declared, or where a function is defined, etc. To jump back, press <C-t>.
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences') -- Find references for the word under your cursor.
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation') -- Jump to the implementation of the word under your cursor. Useful when your language has ways of declaring types without an actual implementation.
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition') -- Jump to the type of the word under your cursor. Useful when you're not sure what type a variable is and you want to see the definition of its *type*, not where it was *defined*.
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols') -- Fuzzy find all the symbols in your current document. Symbols are things like variables, functions, types, etc.
        map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols') -- Fuzzy find all the symbols in your current workspace. Similar to document symbols, except searches over your entire project.
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame') -- Rename the variable under your cursor. Most Language Servers support renaming across files, etc.
        map('<leader>ca', "<cmd>lua require('actions-preview').code_actions()<CR>", '[C]ode [A]ction', { 'n', 'x' }) -- Execute a code action, usually your cursor needs to be on top of an error or a suggestion from your LSP for this to activate.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          map('<leader>ti', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle [I]nlay Hints')
        end
      end,
    })

    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    capabilities.textDocument.foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
    }

    vim.lsp.config('*', { capabilities = capabilities })
    for name, config in pairs(servers) do
      if next(config) ~= nil then
        vim.lsp.config(name, config)
      end
    end

    -- Once now, and again after each direnv environment lands.
    require('direnv').on_load(enable_available)

    vim.api.nvim_create_user_command('LspAvailable', function()
      local names = vim.tbl_keys(enabled)
      table.sort(names)
      vim.notify('enabled language servers:\n  ' .. table.concat(names, '\n  '))
    end, { desc = 'List language servers enabled from the current environment' })
  end,
}
