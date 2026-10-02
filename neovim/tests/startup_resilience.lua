-- Run: nvim --headless '+luafile tests/startup_resilience.lua'
-- Faults are injected in this process; installed plugins/parsers/tools are untouched.
vim.schedule(function()
  local root = vim.fn.tempname() .. '-resilience'
  local ok, err = xpcall(function()
    local lazy = require('lazy.core.config')
    assert(lazy.options.install.missing == false and lazy.options.checker.enabled == false, 'Startup may install/check plugins')
    assert(vim.diagnostic.config().jump.float == nil, 'Deprecated diagnostic jump.float is configured')

    local defer, scheduled = vim.defer_fn, false
    vim.defer_fn = function() scheduled = true end
    require('mason-tool-installer').run_on_start()
    vim.defer_fn = defer
    assert(not scheduled, 'Mason scheduled automatic installation')
    local treesitter, installs = require('nvim-treesitter'), 0
    local install = treesitter.install
    treesitter.install = function() installs = installs + 1 end
    lazy.plugins['nvim-treesitter'].config()
    treesitter.install = install
    assert(installs == 0, 'Tree-sitter installs parsers on startup')

    vim.fn.mkdir(root, 'p')
    vim.cmd('enew')
    vim.api.nvim_buf_set_name(0, root .. '/test.lua')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local value = 1' })
    local notifications = require('fidget.notification')
    notifications.clear_history()
    vim.v.errmsg = ''
    local start = vim.treesitter.start
    vim.treesitter.start = function(buf) return start(buf, 'resilience_missing_parser') end
    local opened, open_error = pcall(function()
      vim.bo.filetype = 'diff'
      vim.api.nvim_exec_autocmds('FileType', { buffer = 0 })
    end)
    vim.treesitter.start = start
    assert(vim.v.errmsg == '', vim.v.errmsg)
    assert(opened, 'Missing parser broke editing: ' .. tostring(open_error))
    assert(vim.bo.syntax == 'diff', 'Missing parser did not fall back to syntax highlighting')
    assert(vim.wait(1000, function() return #notifications.get_history() > 0 end), 'Missing parser warning was hidden')
    local history = notifications.get_history()
    assert(#history == 1 and history[1].message:find(':TSInstall diff', 1, true), 'Parser repair hint missing or repeated')

    vim.bo.filetype = 'lua'
    local conform = require('conform')
    local formatter = conform.formatters.stylua
    conform.formatters.stylua = { command = root .. '/missing-formatter', inherit = false, stdin = true }
    vim.cmd('write')
    assert(vim.deep_equal(vim.fn.readfile(root .. '/test.lua'), { 'local value = 1' }), 'Missing formatter prevented saving')
    assert(vim.wait(1000, function()
      return vim.inspect(notifications.get_history()):find('Formatter unavailable', 1, true) ~= nil
    end), 'Missing formatter repair hint was hidden')
    notifications.clear_history()
    conform.formatters.stylua = { command = '/bin/sh', args = { '-c', 'exit 1' }, inherit = false, stdin = true }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local value = 2' })
    vim.cmd('write')
    conform.formatters.stylua = formatter
    assert(vim.deep_equal(vim.fn.readfile(root .. '/test.lua'), { 'local value = 2' }), 'Failed formatter prevented saving')
    assert(vim.wait(1000, function()
      return vim.inspect(notifications.get_history()):find('Formatter failed', 1, true) ~= nil
    end), 'Formatter execution failure was hidden')
    print('PASS resilience: explicit installs only, missing parser fallback/hint, formatter failures preserve writes and show errors')
  end, debug.traceback)
  vim.fn.delete(root, 'rf')
  if ok then vim.cmd('qa!') else vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end
end)
