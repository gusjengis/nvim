return {
  'neovim/nvim-lspconfig', -- Main LSP Configuration
  dependencies = {
    { 'williamboman/mason.nvim', config = true }, -- Automatically install LSPs and related tools to stdpath for Neovim
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    { 'j-hui/fidget.nvim', opts = {} },
    'hrsh7th/cmp-nvim-lsp', -- Allows extra capabilities provided by nvim-cmp
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
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
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

        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    capabilities.textDocument.foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
    }

    local servers = {
      lua_ls = {
        settings = {
          Lua = { completion = { callSnippet = 'Replace' } },
        },
      },

      rust_analyzer = {
        settings = {
          ['rust_analyzer'] = {
            checkOnSave = true,
            check = { command = 'clippy', extraArgs = { '--no-deps' } },
            procMacro = { enable = true },
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
            },
            imports = { granularity = { group = 'module' }, prefix = 'self' },
            assist = { importGranularity = 'module' },
          },
        },
      },
    }

    require('mason').setup { registries = {
      'github:mason-org/mason-registry',
      'github:Crashdummyy/mason-registry',
    } }
    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, {
      'stylua',
      -- 'python-lsp-server',
      -- 'roslyn',
      'nil',
      -- 'hyprls',
      'wgsl-analyzer',
      'typstyle',
      'tinymist',
    })
    require('mason-lspconfig').setup {
      handlers = {
        -- Force rust-analyzer to use *your* config
        rust_analyzer = function()
          local cfg = servers.rust_analyzer or {}
          cfg.capabilities = vim.tbl_deep_extend('force', {}, capabilities, cfg.capabilities or {})
          require('lspconfig').rust_analyzer.setup(cfg)
        end,

        -- Generic handler for everything else
        function(server_name)
          local cfg = servers[server_name] or {}
          cfg.capabilities = vim.tbl_deep_extend('force', {}, capabilities, cfg.capabilities or {})
          require('lspconfig')[server_name].setup(cfg)
        end,
      },
    }
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }
  end,
}
