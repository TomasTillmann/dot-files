-- Adapted from joelhooks/dotfiles at c3f55039c22e9b36b93c5ba193a5ff406467e001.
-- See README.md for upstream sources, setup, and workflow keys.

-- Leader must be set before plugins load.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Options ]]

-- Make line numbers default
vim.o.number = true
-- Keep long lines on one row and use native horizontal scrolling.
vim.o.wrap = false

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- ponytail: terminal wheel events lack gesture boundaries; infer a new gesture after idle.
local scroll_axis, last_scroll = nil, 0
local scroll_idle_ms = 150
-- Native scrollbind only follows wheel events in the focused window.
for _, direction in ipairs({ 'Up', 'Down', 'Left', 'Right' }) do
  local key = '<ScrollWheel' .. direction .. '>'
  vim.keymap.set({ 'n', 'x', 'i' }, key, function()
    local now = vim.uv.hrtime() / 1e6
    local axis = (direction == 'Left' or direction == 'Right') and 'horizontal' or 'vertical'
    if not scroll_axis or now - last_scroll >= scroll_idle_ms then scroll_axis = axis end
    last_scroll = now
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
vim.o.tabline = "%!v:lua.require('tabline').render()"
-- Keep tab-bar double-clicks from creating empty tabs; retain text selection elsewhere.
vim.keymap.set({ 'n', 'x', 'i', 't' }, '<2-LeftMouse>', function()
  local tabline_visible = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  if tabline_visible and vim.fn.getmousepos().screenrow == 1 then return '' end
  return '<2-LeftMouse>'
end, { expr = true, desc = 'Ignore tab-bar double-click' })
vim.keymap.set('n', '<LeftMouse>', function() return require('diff_base').click() end, { expr = true, desc = 'Click Git comparison to change branch' })
for index = 1, 9 do
  vim.keymap.set('n', tostring(index), function() require('tabline').select(index) end, { desc = 'Go to tab ' .. index })
end
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    if not package.loaded.lazy or #vim.api.nvim_list_uis() == 0 or #vim.api.nvim_list_tabpages() > 1 or vim.fn.argc() > 1 then return end
    local directory = vim.fn.argc() == 0 and vim.fn.getcwd() or vim.fn.argv(0)
    if vim.fn.isdirectory(directory) == 1 then require('tabline').open_workspace(directory) end
  end,
})

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

-- Show which line your cursor is on
vim.o.cursorline = true

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

      vim.keymap.set('n', '?', function()
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
          -- Neo-tree redirects files opened in its window, which otherwise loses the selected line.
          get_selection_window = function()
            if vim.bo.filetype ~= 'neo-tree' then return 0 end
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local buf = vim.api.nvim_win_get_buf(win)
              if vim.api.nvim_win_get_config(win).relative == '' and (vim.bo[buf].buftype == '' or vim.bo[buf].filetype == 'ministarter') then return win end
            end
            vim.cmd.vnew()
            return vim.api.nvim_get_current_win()
          end,
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
      vim.keymap.set('n', '<leader>ss', search.buffer, { desc = 'Search current buffer' })
      vim.keymap.set('n', '<leader>sg', search.grep, { desc = 'Search repository text' })
      vim.keymap.set('n', '<leader>ut', function() builtin.colorscheme({ enable_preview = true }) end, { desc = 'Choose theme (live preview)' })

      -- LSP pickers via Telescope.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
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

      -- Use project Pyright rules and the workspace virtual environment.
      local servers = {
        pyright = {
          -- Workspace members can have pyproject.toml files but share an ancestor's .venv.
          root_markers = { '.venv', 'pyrightconfig.json', 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile', '.git' },
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
      }

      -- Explicit installs only; keep fallback tool versions reproducible.
      require('mason-tool-installer').setup({
        ensure_installed = {
          { 'pyright', version = '1.1.414' },
          { 'ruff', version = '0.15.21' },
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
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then return end
          return 'make install_jsregexp'
        end)(),
        opts = {},
      },
    },
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
        default = { 'lsp', 'path', 'snippets' },
      },

      snippets = { preset = 'luasnip' },

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
          neotree = true,
          mini = { enabled = true },
        },
      })
      vim.cmd.colorscheme('catppuccin')
    end,
  },

  { -- File tree.
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    lazy = false,
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim', 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>b', function() require('side_panel').toggle() end, desc = 'Toggle side panel' },
      { '-', '<cmd>Neotree reveal filesystem left<cr>', desc = 'Reveal current file in tree' },
    },
    opts = {
      close_if_last_window = true,
      enable_git_status = false,
      sources = { 'filesystem', 'buffers' },
      default_component_configs = { diagnostics = { errors_only = true } },
      window = { position = 'left', width = 34, mappings = { ['<space>'] = 'none' } }, -- Space stays the leader inside the tree.
      filesystem = {
        window = { mappings = { ['[g'] = 'none', [']g'] = 'none', ['og'] = 'none' } },
        check_gitignore_in_search = false,
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = { hide_dotfiles = false, hide_gitignored = false, never_show = { '.git' } },
      },
    },
  },

  { -- Changes and history in a dedicated review tab.
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Git diff / working changes' },
      { '<leader>gm', '<cmd>DiffviewOpen origin/main...HEAD --imply-local<cr>', desc = 'Git branch changes vs main' },
      { '<leader>gb', function() require('diff_base').pick() end, desc = 'Git branch changes vs picked branch' },
      { '<leader>gh', '<cmd>DiffviewFileHistory<cr>', desc = 'Git repository history' },
      { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = 'Git current-file history' },
      { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = 'Close Git view' },
    },
    opts = {
      watch_index = false, -- diff_refresh watches index/ref changes without polling.
      show_help_hints = false,
      keymaps = { -- The global Space b (side_panel) toggles the panel; Diffview's Space b/e are disabled.
        view = {
          { 'n', '<C-j>', function() require('diff_navigation').jump(1) end, { desc = 'Next change across files' } },
          { 'n', '<C-k>', function() require('diff_navigation').jump(-1) end, { desc = 'Previous change across files' } },
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

      -- Keep file-tree access available on the starter screen
      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniStarterOpened',
        callback = function(ev) vim.keymap.set('n', '-', '<cmd>Neotree filesystem left<cr>', { buffer = ev.buf, desc = 'Open file tree' }) end,
      })

      starter.setup({
        query_updaters = 'abcdefghijklmnopqrstuvwxyz0_-.', -- Reserve 1–9 for tab switching.
        header = table.concat({
          '┌─────────────────────────────────────┐',
          '│            NEOVIM                   │',
          '└─────────────────────────────────────┘',
        }, '\n'),
        items = {
          { name = 'Find file      f', action = function() require('search').files() end, section = 'Search' },
          { name = 'Find type      t', action = function() require('search').types() end, section = 'Search' },
          { name = 'File tree      -', action = 'Neotree filesystem left', section = 'Files' },
          { name = 'Grep search    g', action = function() require('search').grep() end, section = 'Search' },
          { name = 'Keymaps        k', action = 'Telescope keymaps', section = 'Help' },
          starter.sections.builtin_actions(),
        },
        footer = table.concat({
          '',
          '─────────────────────────────────────────',
          ' -  browse files    <Space>?  search keymaps',
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
        pattern = { 'python', 'sh', 'diff', 'lua', 'markdown', 'query', 'vim', 'help' },
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
}, {
  install = { missing = false }, -- Use :Lazy install / restore explicitly.
  checker = { enabled = false },
  rocks = { enabled = false }, -- No configured plugin requires LuaRocks.
})
-- vim: ts=2 sts=2 sw=2 et
