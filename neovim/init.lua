-- Adapted from joelhooks/dotfiles at c3f55039c22e9b36b93c5ba193a5ff406467e001.
-- See README.md for upstream sources, setup, and workflow keys.

-- Leader must be set before plugins load.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Neo-tree replaces netrw; netrw itself would still list `nvim .` first and leave errors behind.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.api.nvim_create_augroup('FileExplorer', {}) -- Neo-tree clears netrw's group; without it that leaves E216 behind.

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Options ]]

-- Make line numbers default
vim.o.number = true
-- Keep long lines on one row and use native horizontal scrolling.
vim.o.wrap = false

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- kitty sends one wheel event per cell of trackpad travel; scrolling one line/column per event makes the text follow the finger.
vim.o.mousescroll = 'ver:1,hor:1'

-- ponytail: terminal wheel events lack gesture boundaries; infer a new gesture after idle.
local scroll_axis, last_scroll, sideways = nil, 0, 0
local scroll_idle_ms = 150
-- Cells are about half as wide as tall, so a slightly diagonal swipe sends sideways events first.
-- A gesture locks to vertical on its first vertical event; it only goes sideways after this many sideways events with none vertical (about a 45° swipe).
local sideways_to_lock = 4
-- Native scrollbind only follows wheel events in the focused window.
for _, direction in ipairs({ 'Up', 'Down', 'Left', 'Right' }) do
  local key = '<ScrollWheel' .. direction .. '>'
  vim.keymap.set({ 'n', 'x', 'i' }, key, function()
    local now = vim.uv.hrtime() / 1e6
    local axis = (direction == 'Left' or direction == 'Right') and 'horizontal' or 'vertical'
    if now - last_scroll >= scroll_idle_ms then scroll_axis, sideways = nil, 0 end
    last_scroll = now
    if not scroll_axis then
      if axis == 'vertical' then
        scroll_axis = axis
      else
        sideways = sideways + 1
        if sideways < sideways_to_lock then return '' end
        scroll_axis = axis
      end
    end
    if axis ~= scroll_axis then return '' end
    local win = vim.fn.getmousepos().winid
    if win ~= 0 and vim.api.nvim_win_is_valid(win) and vim.wo[win].diff and vim.wo[win].scrollbind then
      return '<Cmd>call win_gotoid(' .. win .. ')<CR>' .. key
    end
    return key
  end, { expr = true, desc = 'Lock scroll direction and synchronize diffs' })
end

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false
-- One view, no tabs: lists and diffs open in place, so the tab bar never shows.
vim.o.showtabline = 0
-- :restart and ZR always start fresh, like opening Neovim again: no session, so no restored windows or tabs.
vim.keymap.set('ca', 'restart', function()
  return vim.fn.getcmdtype() == ':' and vim.fn.getcmdline() == 'restart' and 'restart!' or 'restart'
end, { expr = true, desc = ':restart without restoring the session' })
vim.keymap.set('n', 'ZR', '<cmd>restart!<cr>', { desc = 'Restart Neovim fresh' })

-- Rebalance diff panes after resizing, including tabs resized while hidden.
vim.api.nvim_create_autocmd({ 'VimResized', 'TabEnter' }, {
  group = vim.api.nvim_create_augroup('diffview-equal-widths', { clear = true }),
  callback = function()
    if vim.t.diffview_title then vim.cmd('horizontal wincmd =') end
  end,
})

-- Sync clipboard with the OS; deferred to keep startup fast.
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Show tabs, trailing spaces and non-breaking spaces.
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- No current-line highlight; block cursor in every mode (ThePrimeagen's setup).
vim.o.cursorline = false
vim.o.guicursor = ''

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10
vim.o.foldenable = false -- Keep the full file visible.

-- Ask to save instead of failing on unsaved changes (e.g. `:q`).
vim.o.confirm = true

-- [[ Basic Keymaps ]]

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Show errors only; keep the language server's project rules unchanged.
local error_severity = vim.diagnostic.severity.ERROR
vim.diagnostic.config({
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many', severity = error_severity },
  signs = { severity = error_severity },
  underline = { severity = error_severity },
  virtual_text = false,
  virtual_lines = false,
  jump = {
    severity = error_severity,
    on_jump = function(_, bufnr) vim.diagnostic.open_float({ bufnr = bufnr, scope = 'cursor', focus = false }) end,
  },
})

vim.keymap.set('n', '<leader>q', function()
  if vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 then
    vim.cmd.lclose()
  else
    vim.diagnostic.setloclist({ severity = error_severity, open = false })
    vim.cmd.lopen()
  end
end, { desc = 'Toggle error list' })

-- Easier exit from terminal mode (default is <C-\><C-n>).
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Keybinds to make split navigation easier.
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Basic Autocommands ]]

-- Save normal files when leaving Neovim, including hidden modified buffers.
vim.api.nvim_create_autocmd('FocusLost', {
  desc = 'Save modified files when Neovim loses focus',
  group = vim.api.nvim_create_augroup('kickstart-autosave', { clear = true }),
  nested = true, -- Keep normal write hooks, including format-on-save.
  callback = function()
    for _, info in ipairs(vim.fn.getbufinfo({ bufmodified = 1, bufloaded = 1 })) do
      local bo = vim.bo[info.bufnr]
      if info.name ~= '' and bo.buftype == '' and bo.modifiable and not bo.readonly then
        local ok, err = pcall(vim.api.nvim_buf_call, info.bufnr, function() vim.cmd('silent update') end)
        if not ok then vim.notify('Could not autosave ' .. info.name .. ': ' .. err, vim.log.levels.ERROR) end
      end
    end
  end,
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- [[ Plugins ]]
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.api.nvim_echo({ { 'Plugin manager missing. Using basic editing; follow Dependencies and updates in the config README to install it.', 'ErrorMsg' } }, true, {})
  return
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  { 'NMAC427/guess-indent.nvim', opts = {} },

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    config = function()
      local wk = require('which-key')
      local hints_enabled = false
      wk.setup({
        -- Which-key always waits for the next key; hints only control whether its popup appears.
        delay = function() return hints_enabled and 0 or math.huge end,
        icons = { mappings = vim.g.have_nerd_font },
        spec = {
          { '<leader>a', group = '[A]gents', mode = { 'n', 'x' } },
          { '<leader>s', group = '[S]earch' },
          { '<leader>g', group = '[G]it' },
        },
      })

      vim.keymap.set('n', '<leader>h', function()
        hints_enabled = not hints_enabled
        vim.api.nvim_echo({ { 'Key hints: ' .. (hints_enabled and 'on' or 'off') } }, false, {})
      end, { desc = 'Toggle automatic key hints' })

      vim.keymap.set('n', '<leader>?', '<cmd>Telescope keymaps<cr>', { desc = 'Search all keymaps' })
    end,
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function() return vim.fn.executable('make') == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup({
        defaults = {
          layout_config = { width = 0.98, horizontal = { preview_width = 0.5 } },
          -- Git tabs send files to the Panel tab instead of replacing a diff pane.
          get_selection_window = function() return require('search').selection_window() end,
        },
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      })

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require('telescope.builtin')
      local search = require('search')
      vim.keymap.set('n', '<leader><leader>', function()
        builtin.buffers({ sort_mru = true, sort_lastused = true, ignore_current_buffer = #vim.fn.getbufinfo({ buflisted = 1 }) > 1, prompt_title = 'Recent open files' })
      end, { desc = 'Recent open files' })
      vim.keymap.set('n', '<leader>sf', search.files, { desc = 'Search files' })
      vim.keymap.set('n', '<leader>st', search.types, { desc = 'Search repository types' })
      vim.keymap.set({ 'n', 'x' }, '<leader>ss', search.buffer, { desc = 'Search current buffer (selection prefilled)' })
      vim.keymap.set('n', '<leader>sg', search.grep, { desc = 'Search repository text' })
      vim.keymap.set('n', '<leader>ut', function() builtin.colorscheme({ enable_preview = true }) end, { desc = 'Choose theme (live preview)' })

      -- LSP pickers via Telescope.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
          vim.keymap.set('n', 'grc', builtin.lsp_incoming_calls, { buffer = buf, desc = '[G]oto [C]allers: functions that call this one' })
          vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
          vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
          vim.keymap.set('n', 'gd', builtin.lsp_definitions, { buffer = buf, desc = 'Go to definition' })
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
        end,
      })
    end,
  },

  { -- LSP configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = { notification = { override_vim_notify = true, filter = vim.log.levels.ERROR } } },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      -- Buffer-local LSP keymaps and reference highlighting.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Highlight references to the symbol under the cursor while it rests.
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
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
                vim.api.nvim_clear_autocmds({ group = 'kickstart-lsp-highlight', buffer = event2.buf })
              end,
            })
          end
        end,
      })

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Workspace members can have pyproject.toml files but share an ancestor's .venv.
      local python_root_markers = { '.venv', 'pyrightconfig.json', 'ty.toml', 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile', '.git' }

      -- ty answers navigation, hover, completion and symbols; Pyright reports the same errors as the project's typecheck task.
      local servers = {
        ty = {
          root_markers = python_root_markers,
          -- No diagnostics from ty: drop both pushed and pulled results.
          handlers = { ['textDocument/publishDiagnostics'] = function() end, ['textDocument/diagnostic'] = function() end },
          cmd = function(dispatchers, config)
            local root = config.root_dir or vim.fn.getcwd()
            local venv = root .. '/.venv'
            -- Prefer the project's own ty; Mason's pinned ty is the fallback.
            local ty = vim.fn.executable(venv .. '/bin/ty') == 1 and venv .. '/bin/ty' or 'ty'
            local env = config.cmd_env
            if vim.fn.executable(venv .. '/bin/python') == 1 then
              -- Select this project's .venv even when Neovim was started from another activated environment.
              env = vim.tbl_extend('force', env or {}, { VIRTUAL_ENV = venv })
            end
            return vim.lsp.rpc.start({ ty, 'server' }, dispatchers, { cwd = root, env = env })
          end,
        },
        pyright = {
          root_markers = python_root_markers,
          -- Diagnostics only: keep document sync and workspace features, drop navigation/completion so ty's results aren't duplicated.
          on_init = function(client)
            local caps = client.server_capabilities
            client.server_capabilities = { textDocumentSync = caps.textDocumentSync, diagnosticProvider = caps.diagnosticProvider, workspace = caps.workspace }
          end,
          cmd = function(dispatchers, config)
            local root = config.root_dir or vim.fn.getcwd()
            local python = root .. '/.venv/bin/python'
            local command = { 'pyright-langserver', '--stdio' }
            if vim.fn.executable(root .. '/.venv/bin/pyright-langserver') == 1 then
              -- Honor the same environment/version pin as the repository's Poe typecheck task.
              command = { python, '-c', [[
import os, pathlib, tomllib
from pyright.langserver import entrypoint
path = pathlib.Path('pyproject.toml')
config = tomllib.loads(path.read_text()) if path.exists() else {}
task = config.get('tool', {}).get('poe', {}).get('tasks', {}).get('typecheck', {})
if isinstance(task, dict):
    os.environ.update(task.get('env', {}))
entrypoint()
]], '--stdio' }
            end
            return vim.lsp.rpc.start(command, dispatchers, { cwd = root, env = config.cmd_env })
          end,
          before_init = function(_, config)
            local python = (config.root_dir or vim.fn.getcwd()) .. '/.venv/bin/python'
            if vim.fn.executable(python) == 1 then config.settings.python.pythonPath = python end
          end,
        },
        ruff = {
          -- Only repositories that configure Ruff get its lint results, using that configuration (as CI does).
          root_dir = function(bufnr, on_dir)
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name == '' then return end
            local configs = vim.fs.find({ 'ruff.toml', '.ruff.toml', 'pyproject.toml' }, { upward = true, path = vim.fs.dirname(name), limit = math.huge })
            for _, config in ipairs(configs) do
              if not vim.endswith(config, 'pyproject.toml') or table.concat(vim.fn.readfile(config), '\n'):find('[tool.ruff', 1, true) then
                return on_dir(vim.fs.root(bufnr, python_root_markers))
              end
            end
          end,
          -- Ruff reports lint as warnings; show them as errors since CI fails on them.
          handlers = (function()
            local function as_errors(method)
              return function(err, result, ctx)
                for _, diagnostic in ipairs(result and (result.diagnostics or result.items) or {}) do
                  diagnostic.severity = vim.lsp.protocol.DiagnosticSeverity.Error
                end
                return vim.lsp.handlers[method](err, result, ctx)
              end
            end
            return { ['textDocument/publishDiagnostics'] = as_errors('textDocument/publishDiagnostics'), ['textDocument/diagnostic'] = as_errors('textDocument/diagnostic') }
          end)(),
          -- ty supplies hover; Ruff keeps diagnostics and its fix/organize-imports code actions.
          on_init = function(client) client.server_capabilities.hoverProvider = nil end,
          cmd = function(dispatchers, config)
            local root = config.root_dir or vim.fn.getcwd()
            -- Prefer the project's own Ruff so rules and versions match CI; Mason's is the fallback.
            local ruff = vim.fn.executable(root .. '/.venv/bin/ruff') == 1 and root .. '/.venv/bin/ruff' or 'ruff'
            return vim.lsp.rpc.start({ ruff, 'server' }, dispatchers, { cwd = root, env = config.cmd_env })
          end,
        },
        lua_ls = {},
      }

      -- Explicit installs only; keep fallback tool versions reproducible.
      require('mason-tool-installer').setup({
        ensure_installed = {
          { 'ty', version = '0.0.85' },
          { 'pyright', version = '1.1.414' },
          { 'ruff', version = '0.15.21' },
          { 'lua-language-server', version = '3.19.1' },
          { 'stylua', version = 'v2.5.2' },
          { 'tree-sitter-cli', version = 'v0.26.11' },
        },
        run_on_start = false,
        auto_update = false,
      })

      for name, server in pairs(servers) do
        server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end
    end,
  },

  { -- Neovim API and plugin types for lua_ls when editing Lua.
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } },
  },

  { -- Git change markers, hunk actions and line blame in ordinary buffers.
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      on_attach = function(buf)
        local gitsigns = require('gitsigns')
        local function map(mode, keys, func, desc) vim.keymap.set(mode, keys, func, { buffer = buf, desc = desc }) end
        local function selection() return { vim.fn.line('.'), vim.fn.line('v') } end
        map('n', ']h', function() gitsigns.nav_hunk('next') end, 'Next Git change')
        map('n', '[h', function() gitsigns.nav_hunk('prev') end, 'Previous Git change')
        map('n', '<leader>gp', gitsigns.preview_hunk, 'Git preview change')
        map('n', '<leader>gs', gitsigns.stage_hunk, 'Git stage/unstage change')
        map('x', '<leader>gs', function() gitsigns.stage_hunk(selection()) end, 'Git stage/unstage selection')
        map('n', '<leader>gr', gitsigns.reset_hunk, 'Git reset change')
        map('x', '<leader>gr', function() gitsigns.reset_hunk(selection()) end, 'Git reset selection')
        map('n', '<leader>gl', function() gitsigns.blame_line({ full = true }) end, 'Git blame line')
      end,
    },
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format({ async = true, lsp_format = 'fallback' }) end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = true,
      format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == 'python' or ft == 'lua' then
          local formatters, lsp = require('conform').list_formatters_to_run(bufnr)
          if #formatters == 0 and not lsp then
            vim.notify_once('Formatter unavailable for ' .. ft .. '. Run :MasonToolsInstall and check :ConformInfo.', vim.log.levels.ERROR)
            return
          end
        end
        -- C/C++ have no standard style; skip format-on-save there.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_format' },
      },
      -- Format with the project's own Ruff when installed, matching CI's format check.
      formatters = {
        ruff_format = { command = function(self, ctx) return require('conform.util').find_executable({ '.venv/bin/ruff' }, 'ruff')(self, ctx) end },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        preset = 'default',
      },

      appearance = {
        nerd_font_variant = 'mono',
      },

      completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = { lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 } },
      },

      -- Built-in vim.snippet expands LSP snippets; no separate snippet engine.
      snippets = { preset = 'default' },

      -- Lua matcher avoids downloading the prebuilt Rust binary.
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  { -- Catppuccin colorscheme
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup({
        flavour = 'mocha', -- latte, frappe, macchiato, mocha
        no_italic = true,
        custom_highlights = function(colors)
          local blend = require('catppuccin.utils.colors').blend
          return {
            DiffChange = { bg = blend(colors.yellow, colors.base, 0.20) },
            DiffText = { bg = blend(colors.yellow, colors.base, 0.38) },
            DiffTextAdd = { link = 'DiffText' },
          }
        end,
        integrations = {
          telescope = true,
          treesitter = true,
          which_key = true,
          mini = { enabled = true },
          neotree = true,
        },
      })
    end,
  },

  { -- Rose Pine colorscheme (startup default)
    'rose-pine/neovim',
    name = 'rose-pine',
    priority = 1000,
    config = function()
      require('rose-pine').setup({
        variant = 'main', -- main, moon (dawn is picked via :colorscheme rose-pine-dawn)
        disable_background = true, -- ThePrimeagen style: transparent, terminal background shows through
        disable_float_background = true,
        styles = { bold = false, italic = false },
        -- Softer, warmer tones measured from ThePrimeagen's videos, with saturation raised slightly;
        -- rose-pine-moon/dawn keep stock colors.
        palette = {
          main = {
            base = '#0b0800',
            surface = '#16130e',
            overlay = '#221e19',
            muted = '#6a6674',
            subtle = '#8b8992',
            text = '#d2ccdb',
            love = '#c46b78',
            gold = '#d8ae9b',
            rose = '#d9afac',
            pine = '#6a9680',
            foam = '#b8d1c3',
            iris = '#c8a8bc',
          },
        },
        -- In his videos calls are rose like definitions, and attributes are iris.
        highlight_groups = {
          ['@function.call'] = { fg = 'rose' },
          ['@function.method.call'] = { fg = 'rose' },
          ['@variable.member'] = { fg = 'iris' },
          ['@property'] = { fg = 'iris' },
          -- ty marks imported modules as namespaces; color them in a warm amber gold instead of plain text.
          ['@lsp.type.namespace.python'] = { fg = '#dfa548' },
          -- Sticky scroll lines keep the editor's own background, with no line underneath; their line numbers are a step dimmer than the rest.
          TreesitterContext = { bg = 'NONE' },
          TreesitterContextLineNumber = { fg = 'highlight_high', bg = 'NONE' },
          TreesitterContextBottom = { underline = false },
          TreesitterContextLineNumberBottom = { underline = false },
        },
      })
      vim.cmd.colorscheme('rose-pine')
    end,
  },

  { -- Folder tree on demand: Space e shows it full-window in place of the current buffer; no docked side panel.
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    lazy = false, -- Replaces netrw, so `nvim .` and :edit on a directory show the tree.
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim', 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>e', function() require('file_tree').toggle() end, desc = 'Toggle file tree' },
    },
    opts = {
      enable_git_status = false,
      sources = { 'filesystem' },
      default_component_configs = { diagnostics = { errors_only = true } },
      window = { mappings = { ['<space>'] = 'none', ['Z'] = function(state) require('file_tree').expand_all(state) end } }, -- Space stays the leader inside the tree; Z opens every folder under the cursor except .venv and caches.
      -- Yazi-style live preview of the file under the cursor (lua/file_tree.lua).
      event_handlers = {
        { event = 'neo_tree_buffer_enter', handler = function() require('file_tree').attach_preview(vim.api.nvim_get_current_buf()) end },
        { event = 'after_render', handler = function(state) require('file_tree').after_render(state) end },
      },
      filesystem = {
        hijack_netrw_behavior = 'open_current', -- A directory buffer becomes the tree in the same window.
        window = { -- P toggles the live preview; Ctrl-d/u scroll it; l moves into it.
          mappings = {
            ['[g'] = 'none', [']g'] = 'none', ['og'] = 'none',
            ['P'] = function(state) require('file_tree').toggle_preview(state) end,
            ['<C-d>'] = function(state) require('file_tree').scroll_preview(state, '<C-d>') end,
            ['<C-u>'] = function(state) require('file_tree').scroll_preview(state, '<C-u>') end,
            ['<C-f>'] = function(state) require('file_tree').scroll_preview(state, '<C-d>') end,
            ['<C-b>'] = function(state) require('file_tree').scroll_preview(state, '<C-u>') end,
            ['l'] = function(state) require('file_tree').focus_preview(state) end,
          },
        },
        check_gitignore_in_search = false,
        use_libuv_file_watcher = true,
        -- Dotfiles and gitignored files (.venv, caches) start hidden; H shows or hides them. .git is never shown.
        filtered_items = { hide_dotfiles = true, hide_gitignored = true, never_show = { '.git' } },
      },
    },
  },

  { -- Side-by-side diffs for the Git lists (lua/git_view.lua), full view without Diffview's file panel.
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
    keys = {
      { '<leader>gg', function() require('git_view').changes() end, desc = 'Git current changes' },
      { '<leader>gm', function() require('git_view').against() end, desc = 'Git changes against main' },
      { '<leader>gb', function() require('diff_base').pick() end, desc = 'Git changes against a picked branch' },
      { '<leader>gh', function() require('git_view').history() end, desc = 'Git commit history' },
      { '<leader>gf', function() require('git_view').file_history() end, desc = 'Git current-file history' },
      { '<leader>gq', function() require('git_view').close_diff() end, desc = 'Close Git diff' },
    },
    opts = {
      watch_index = false, -- diff_refresh watches index/ref changes without polling.
      show_help_hints = false,
      keymaps = { -- The file panel stays closed: Diffview's panel keys are disabled; q returns to the list.
        view = {
          { 'n', '<C-j>', function() require('diff_navigation').jump(1) end, { desc = 'Next change across files' } },
          { 'n', '<C-k>', function() require('diff_navigation').jump(-1) end, { desc = 'Previous change across files' } },
          { 'n', 'q', function() require('git_view').close_diff() end, { desc = 'Back to the Git list' } },
          { 'n', '<leader>b', false },
          { 'n', '<leader>e', false },
        },
        file_panel = { { 'n', '<leader>b', false }, { 'n', '<leader>e', false } },
        file_history_panel = { { 'n', '<leader>b', false }, { 'n', '<leader>e', false } },
      },
      hooks = {
        view_opened = function(view)
          vim.t[view.tabpage].diffview_title = view.rev_arg and ('Changes against ' .. view.rev_arg:gsub('%.%.%.HEAD$', ''):gsub('^origin/', ''))
            or (view.update_files and 'Current Changes' or 'History')
          require('git_view').view_opened(view)
          require('diff_refresh').start(view)
        end,
        view_closed = function(view) require('diff_refresh').stop(view) end,
        diff_buf_win_enter = function() vim.wo.foldenable = false end,
      },
      file_panel = { listing_style = 'tree', win_config = { position = 'left', width = 34 } },
      file_history_panel = { win_config = { position = 'left', width = 34 } },
    },
  },

  {
    'akinsho/toggleterm.nvim',
    version = '*',
    cmd = { 'ToggleTerm', 'TermSelect' },
    keys = {
      { '<leader>t', function() require('popup_terminal').toggle() end, desc = 'Open floating terminal' },
    },
    opts = {
      open_mapping = false,
      insert_mappings = false,
      start_in_insert = true,
      persist_mode = false,
      env = { NVIM_POPUP_TERMINAL = '1' },
      on_create = function(term)
        vim.api.nvim_create_autocmd('TermLeave', {
          buffer = term.bufnr,
          callback = function()
            vim.schedule(function()
              if term:is_focused() then vim.cmd.startinsert() end
            end)
          end,
        })
      end,
      on_open = function(term)
        require('popup_terminal').on_open(term)
        -- ponytail: one-line URLs only; use wrap metadata if Neovim exposes it.
        vim.keymap.set({ 'n', 't' }, '<LeftMouse>', function()
          local mouse = vim.fn.getmousepos()
          if require('popup_terminal').click_title(term, mouse) then return '' end
          if mouse.winid == term.window and mouse.line > 0 then
            local line = vim.api.nvim_buf_get_lines(term.bufnr, mouse.line - 1, mouse.line, false)[1] or ''
            for first, url, last in line:gmatch('()(https?://[^%s<>"\']+)()') do
              if mouse.column >= first and mouse.column < last then
                vim.schedule(function()
                  local _, err = vim.ui.open(url)
                  if err then vim.notify(err, vim.log.levels.ERROR) end
                end)
                return ''
              end
            end
          end
          return '<LeftMouse>'
        end, { buffer = term.bufnr, expr = true, desc = 'Open terminal URL in browser' })
      end,
      direction = 'float',
      float_opts = {
        border = 'rounded',
        title_pos = 'center',
        width = function() return math.floor(vim.o.columns * 0.9) end,
        height = function() return math.floor(vim.o.lines * 0.9) end,
      },
    },
  },

  {
    'karb94/neoscroll.nvim',
    event = 'VimEnter',
    opts = { mappings = { '<C-b>', '<C-f>', '<C-y>', '<C-e>', 'zt', 'zz', 'zb' }, easing = 'quadratic' },
    config = function(_, opts)
      local scroll = require('neoscroll')
      scroll.setup(opts)
      vim.keymap.set('n', '<C-d>', function() scroll.scroll(10, { move_cursor = true, duration = 120 }) end, { desc = 'Scroll down 10 lines' })
      vim.keymap.set('n', '<C-u>', function() scroll.scroll(-10, { move_cursor = true, duration = 120 }) end, { desc = 'Scroll up 10 lines' })
    end,
  },

  { -- Agent CLI sessions only; no Copilot or AI completion.
    'folke/sidekick.nvim',
    cmd = 'Sidekick',
    opts = {
      nes = { enabled = false },
      cli = { mux = { backend = 'tmux', enabled = true }, picker = 'telescope' },
    },
    keys = {
      { '<leader>aa', function() require('sidekick.cli').toggle({ filter = { installed = true } }) end, desc = 'Toggle agent terminal' },
      { '<leader>as', function() require('sidekick.cli').select({ filter = { installed = true } }) end, desc = 'Select agent/session' },
      { '<leader>ad', function() require('sidekick.cli').close() end, desc = 'Detach agent session' },
      { '<leader>af', function() require('sidekick.cli').send({ msg = '{file}' }) end, desc = 'Add current file to agent' },
      { '<leader>av', function() require('sidekick.cli').send({ msg = '{selection}' }) end, mode = 'x', desc = 'Add selection to agent' },
      { '<leader>ap', function() require('sidekick.cli').prompt() end, mode = { 'n', 'x' }, desc = 'Agent prompts/context' },
    },
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'nvim-mini/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      require('mini.ai').setup({ n_lines = 500 })

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      require('mini.surround').setup()

      -- Simple statusline
      local statusline = require('mini.statusline')
      statusline.setup({ use_icons = vim.g.have_nerd_font })
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function() return '%2l:%-2v' end
      statusline.section_diagnostics = function(args)
        if statusline.is_truncated(args.trunc_width) or not vim.diagnostic.is_enabled({ bufnr = 0 }) then return '' end
        local count = vim.diagnostic.count(0, { severity = vim.diagnostic.severity.ERROR })[vim.diagnostic.severity.ERROR] or 0
        return count > 0 and ('E' .. count) or ''
      end

      -- Start screen with essential keybinds
      local starter = require('mini.starter')

      -- The letters shown next to start-screen items open them directly (instead of filtering by name).
      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniStarterOpened',
        callback = function()
          -- At startup this event is delayed, so the current buffer may no longer be the start screen.
          local buf = vim.iter(vim.api.nvim_list_bufs()):find(function(b) return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == 'ministarter' end)
          if not buf then return end
          local function map(key, action, desc) vim.keymap.set('n', key, action, { buffer = buf, desc = desc }) end
          map('f', function() require('search').files() end, 'Find file')
          map('t', function() require('search').types() end, 'Find type')
          map('g', function() require('search').grep() end, 'Grep search')
          map('k', '<cmd>Telescope keymaps<cr>', 'Keymaps')
          map('e', function() require('file_tree').toggle() end, 'File tree')
        end,
      })

      starter.setup({
        query_updaters = 'abcdhijlmnopqrsuvwxyz0_.', -- f/t/g/k/e are shortcuts; 1–9 switch tabs.
        header = table.concat({
          '┌─────────────────────────────────────┐',
          '│            NEOVIM                   │',
          '└─────────────────────────────────────┘',
        }, '\n'),
        items = {
          { name = 'Find file      f', action = function() require('search').files() end, section = 'Search' },
          { name = 'Find type      t', action = function() require('search').types() end, section = 'Search' },
          { name = 'File tree      e', action = function() require('file_tree').toggle() end, section = 'Files' },
          { name = 'Grep search    g', action = function() require('search').grep() end, section = 'Search' },
          { name = 'Keymaps        k', action = 'Telescope keymaps', section = 'Help' },
          starter.sections.builtin_actions(),
        },
        footer = table.concat({
          '',
          '─────────────────────────────────────────',
          ' <Space>e  file tree    <Space>?  keymaps',
          '─────────────────────────────────────────',
        }, '\n'),
        content_hooks = {
          starter.gen_hook.adding_bullet(''),
          starter.gen_hook.aligning('center', 'center'),
        },
      })
    end,
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup({ install_dir = vim.fn.stdpath('data') .. '/site' })
      local warned = {}
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('kickstart-treesitter', { clear = true }),
        pattern = { 'python', 'sh', 'bash', 'diff', 'lua', 'markdown', 'query', 'vim', 'help', 'toml', 'yaml', 'json', 'jsonc', 'dockerfile', 'gitcommit' },
        callback = function(ev)
          local ok, err = pcall(vim.treesitter.start, ev.buf)
          if ok then return end
          vim.bo[ev.buf].syntax = ev.match
          if not warned[ev.match] then
            warned[ev.match] = true
            local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
            vim.notify('Syntax highlighting unavailable for ' .. ev.match .. '. Run :TSInstall ' .. lang .. ' to repair it. ' .. tostring(err), vim.log.levels.ERROR)
          end
        end,
      })
    end,
  },

  { -- Sticky scroll, like VS Code: the class/function lines enclosing the cursor stay pinned at the top once their start scrolls away.
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      max_lines = 5, -- At most five nested scopes.
      multiline_threshold = 1, -- One line per scope, even for multi-line signatures.
      trim_scope = 'outer', -- When nesting exceeds max_lines, drop the outermost scopes.
    },
  },
}, {
  install = { missing = false }, -- Use :Lazy install / restore explicitly.
  checker = { enabled = false },
  rocks = { enabled = false }, -- No configured plugin requires LuaRocks.
})
-- vim: ts=2 sts=2 sw=2 et
