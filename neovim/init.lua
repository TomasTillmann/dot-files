-- Adapted from joelhooks/dotfiles at c3f55039c22e9b36b93c5ba193a5ff406467e001.
-- See README.md for upstream sources, setup, and workflow keys.
--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
-- (Most modern dev setups do - if icons look broken, set to false)
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- Keep long lines on one row and use native horizontal scrolling.
vim.o.wrap = false
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
-- vim.o.relativenumber = true

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

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
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

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-guide-options`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10
vim.o.foldenable = false -- Keep the full file visible.

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
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

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

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
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- [[ Load the installed `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.api.nvim_echo({ { 'Plugin manager missing. Using basic editing; follow Dependencies and updates in the config README to install it.', 'ErrorMsg' } }, true, {})
  return
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added via a link or github org/name. To run setup automatically, use `opts = {}`
  { 'NMAC427/guess-indent.nvim', opts = {} },

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    config = function()
      local wk = require('which-key')
      local hints_enabled = false
      wk.setup({
        delay = 0,
        filter = function() return hints_enabled end,
        icons = { mappings = vim.g.have_nerd_font },
        spec = {
          { '<leader>a', group = '[A]gents', mode = { 'n', 'x' } },
          { '<leader>s', group = '[S]earch' },
          { '<leader>g', group = '[G]it' },
        },
      })

      vim.keymap.set('n', '?', function()
        hints_enabled = not hints_enabled
        wk.add({}) -- Rebuild cached hints using the updated filter.
        vim.api.nvim_echo({ { 'Key hints: ' .. (hints_enabled and 'on' or 'off') } }, false, {})
      end, { desc = 'Toggle automatic key hints' })

      vim.keymap.set('n', '<leader>?', '<cmd>Telescope keymaps<cr>', { desc = 'Search all keymaps' })
    end,
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    -- By default, Telescope is included and acts as your picker for everything.

    -- If you would like to switch to a different picker (like snacks, or fzf-lua)
    -- you can disable the Telescope plugin by setting enabled to false and enable
    -- your replacement picker by requiring it explicitly (e.g. 'custom.plugins.snacks')

    -- Note: If you customize your config for yourself,
    -- it’s best to remove the Telescope plugin config entirely
    -- instead of just disabling it here, to keep your config clean.
    enabled = true,
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function() return vim.fn.executable('make') == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
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

      -- See `:help telescope.builtin`
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

      -- This runs on LSP attach per buffer (see main LSP attach function in 'neovim/nvim-lspconfig' config for more info,
      -- it is better explained there). This allows easily switching between pickers if you prefer using something else!
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf

          -- Find references for the word under your cursor.
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

          -- Jump to the implementation of the word under your cursor.
          -- Useful when your language has ways of declaring types without an actual implementation.
          vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

          -- Jump to the definition of the word under your cursor.
          -- This is where a variable was first declared, or where a function is defined, etc.
          -- To jump back, press <C-t>.
          vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
          vim.keymap.set('n', 'gd', builtin.lsp_definitions, { buffer = buf, desc = 'Go to definition' })
          -- Jump to the type of the word under your cursor.
          -- Useful when you're not sure what type a variable is and you want to see
          -- the definition of its *type*, not where it was *defined*.
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
        end,
      })
    end,
  },

  -- LSP Plugins
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'mason-org/mason.nvim', opts = {} },
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = { notification = { override_vim_notify = true, filter = vim.log.levels.ERROR } } },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
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

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --  See `:help lsp-config` for information about keys and how to configure
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
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
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
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
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
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then return end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
        opts = {},
      },
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets' },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
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
      { '<leader>e', '<cmd>Neotree toggle filesystem reveal left<cr>', desc = 'File tree' },
      { '-', '<cmd>Neotree reveal filesystem left<cr>', desc = 'Reveal current file in tree' },
    },
    opts = {
      close_if_last_window = true,
      enable_git_status = false,
      sources = { 'filesystem', 'buffers' },
      default_component_configs = { diagnostics = { errors_only = true } },
      window = { position = 'left', width = 34 },
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
      { '<leader>gh', '<cmd>DiffviewFileHistory<cr>', desc = 'Git repository history' },
      { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = 'Git current-file history' },
      { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = 'Close Git view' },
    },
    opts = {
      watch_index = false, -- diff_refresh watches index/ref changes without polling.
      show_help_hints = false,
      keymaps = {
        view = {
          { 'n', '<C-j>', function() require('diff_navigation').jump(1) end, { desc = 'Next change across files' } },
          { 'n', '<C-k>', function() require('diff_navigation').jump(-1) end, { desc = 'Previous change across files' } },
        },
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
      file_panel = { listing_style = 'list', win_config = { position = 'left', width = 34 } },
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

      -- Use the documented Git summary hook to show only the branch name.
      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniGitUpdated',
        callback = function(ev)
          local head = vim.b[ev.buf].minigit_summary.head_name or ''
          vim.b[ev.buf].minigit_summary_string = head:gsub('%%', '%%%%')
        end,
      })
      require('mini.git').setup()

      -- Keep the default statusline sections, with Git at the far right.
      local statusline = require('mini.statusline')
      statusline.setup({
        use_icons = vim.g.have_nerd_font,
        content = {
          active = function()
            local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
            return statusline.combine_groups({
              { hl = mode_hl, strings = { mode } },
              { hl = 'MiniStatuslineDevinfo', strings = {
                statusline.section_diff({ trunc_width = 75 }),
                statusline.section_diagnostics({ trunc_width = 75 }),
                statusline.section_lsp({ trunc_width = 75 }),
              } },
              '%<',
              { hl = 'MiniStatuslineFilename', strings = { statusline.section_filename({ trunc_width = 140 }) } },
              '%=',
              { hl = 'MiniStatuslineFileinfo', strings = { statusline.section_fileinfo({ trunc_width = 120 }) } },
              { hl = mode_hl, strings = { statusline.section_searchcount({ trunc_width = 75 }), statusline.section_location({ trunc_width = 75 }) } },
              { hl = 'MiniStatuslineDevinfo', strings = { statusline.section_git({ trunc_width = 0 }) } },
            })
          end,
        },
      })
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

  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  -- require 'kickstart.plugins.neo-tree',

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  -- { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  install = { missing = false }, -- Use :Lazy install / restore explicitly.
  checker = { enabled = false },
  rocks = { enabled = false }, -- No configured plugin requires LuaRocks.
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
