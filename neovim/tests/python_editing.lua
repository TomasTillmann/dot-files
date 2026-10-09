-- Run: env -u VIRTUAL_ENV nvim --headless '+luafile tests/python_editing.lua'
-- Everyday Python editing through the real keys: navigation, hover, references, completion,
-- rename, Ruff quick fix and format-on-save. The project lives in Neovim's temporary directory.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then
    vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err)))
    vim.api.nvim_err_writeln('LSP log: ' .. vim.lsp.log.get_filename())
    vim.cmd('cquit 1')
  end
end
local function pause(ms) vim.defer_fn(resume, ms); coroutine.yield() end
local function wait(predicate, message, seconds)
  local deadline = vim.uv.hrtime() + (seconds or 30) * 1e9
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message)
    pause(25)
  end
end
local function keys(text) vim.api.nvim_input(text); pause(50) end
local function line(n) return vim.api.nvim_buf_get_lines(0, n - 1, n, false)[1] end
local function cursor_on(row, word)
  vim.api.nvim_win_set_cursor(0, { row, assert(line(row):find(word, 1, true), word .. ' not on line ' .. row) - 1 })
end
local function command(argv)
  local result = vim.system(argv, { text = true }):wait(60000)
  assert(result.code == 0, table.concat(argv, ' ') .. ': ' .. (result.stderr or 'failed'))
end

runner = coroutine.create(function()
  assert(not vim.env.VIRTUAL_ENV or vim.env.VIRTUAL_ENV == '', 'Run with VIRTUAL_ENV unset')
  local root = vim.fn.tempname() .. '-nvim-python-editing'
  vim.fn.mkdir(root, 'p')
  root = assert(vim.uv.fs_realpath(root))
  vim.fn.writefile({ '[project]', 'name = "editing"', 'version = "0.0.0"', '[tool.ruff.lint]', 'select = ["F401"]' }, root .. '/pyproject.toml')
  command({ 'uv', 'venv', '--quiet', '--no-project', '--no-python-downloads', root .. '/.venv' })
  local models, app = root .. '/models.py', root .. '/app.py'
  vim.fn.writefile({
    'class Widget:',
    '    def __init__(self, name: str) -> None:',
    '        self.name = name',
  }, models)
  vim.fn.writefile({
    'import os',
    'from models import Widget',
    '',
    '',
    'def build() -> Widget:',
    '    widget = Widget("demo")',
    '    return widget',
  }, app)
  vim.cmd.cd(vim.fn.fnameescape(root))
  vim.cmd.edit(vim.fn.fnameescape(app))
  local buf = vim.api.nvim_get_current_buf()
  wait(function()
    for _, name in ipairs({ 'ty', 'pyright', 'ruff' }) do
      local client = vim.lsp.get_clients({ bufnr = buf, name = name })[1]
      if not (client and client.initialized) then return false end
    end
    return true
  end, 'ty, Pyright and Ruff did not all attach')
  local function back_to_app()
    vim.cmd.buffer(buf)
    assert(vim.api.nvim_buf_get_name(0) == app)
  end

  -- gd: go to definition.
  cursor_on(6, 'Widget(')
  keys('gd')
  wait(function() return vim.api.nvim_buf_get_name(0) == models and vim.fn.line('.') == 1 end, 'gd did not jump to the Widget class')
  back_to_app()

  -- grt: go to type definition of a variable.
  cursor_on(7, 'widget')
  keys('grt')
  wait(function() return vim.api.nvim_buf_get_name(0) == models and vim.fn.line('.') == 1 end, 'grt did not jump to the Widget type')
  back_to_app()
  print('PASS navigation: gd and grt')

  -- K: hover documentation in a float.
  cursor_on(7, 'widget')
  keys('K')
  local hover_win
  wait(function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative ~= '' then
        local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), '\n')
        if text:find('Widget', 1, true) then hover_win = win; return true end
      end
    end
  end, 'K did not show hover for widget')
  vim.api.nvim_win_close(hover_win, true)
  print('PASS hover: K shows the type')

  -- grr: references picker lists the import and the usage.
  cursor_on(6, 'Widget(')
  keys('grr')
  wait(function() return vim.bo.filetype == 'TelescopePrompt' end, 'grr did not open the references picker')
  local prompt = vim.api.nvim_get_current_buf()
  local picker = require('telescope.actions.state').get_current_picker(prompt)
  wait(function() return picker.manager and picker.manager:num_results() >= 3 end, 'References picker did not list the import, return type and call')
  require('telescope.actions').close(prompt)
  wait(function() return vim.bo.filetype ~= 'TelescopePrompt' end, 'References picker did not close')
  back_to_app()
  print('PASS references: grr lists every use')

  -- Completion: typing a member shows the menu; Ctrl-y accepts.
  vim.api.nvim_win_set_cursor(0, { 6, 0 })
  keys('olabel = widget.na')
  wait(function() return require('blink.cmp').is_menu_visible() end, 'Completion menu did not appear')
  keys('<C-y>')
  wait(function() return line(7) == '    label = widget.name' end, 'Ctrl-y did not accept the completion: ' .. tostring(line(7)))
  keys('<Esc>')
  wait(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Did not return to Normal mode')
  print('PASS completion: member suggestions, Ctrl-y accepts')

  -- grn: rename a local across the function.
  cursor_on(6, 'widget')
  keys('grn')
  wait(function() return vim.fn.mode() == 'c' end, 'grn did not prompt for a new name')
  keys('<C-u>item<CR>')
  wait(function() return line(6) == '    item = Widget("demo")' and line(7) == '    label = item.name' and line(8) == '    return item' end,
    'grn did not rename every use: ' .. table.concat(vim.api.nvim_buf_get_lines(0, 5, 8, false), ' | '))
  print('PASS rename: grn renames every use')

  -- gra: apply Ruff's quick fix for the configured unused-import rule.
  wait(function()
    for _, diagnostic in ipairs(vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })) do
      if diagnostic.code == 'F401' and diagnostic.lnum == 0 then return true end
    end
  end, 'Ruff F401 error was not shown for the unused import')
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  keys('gra')
  wait(function() return vim.bo.filetype == 'TelescopePrompt' end, 'gra did not open the code-action picker')
  keys('Remove unused')
  pause(300)
  keys('<CR>')
  wait(function() return vim.api.nvim_get_current_buf() == buf and line(1) == 'from models import Widget' end, 'Ruff quick fix did not remove the unused import: ' .. tostring(line(1)))
  print('PASS code actions: gra applies the Ruff fix')

  -- Format on save with Ruff.
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, { 'numbers=[1,2,  3]' })
  vim.cmd.write()
  wait(function() return vim.fn.readfile(app)[#vim.fn.readfile(app)] == 'numbers = [1, 2, 3]' end, 'Python was not formatted on save')

  -- Format on save with StyLua.
  local lua_file = root .. '/probe.lua'
  vim.fn.writefile({ 'local  value=1', 'return value' }, lua_file)
  vim.cmd.edit(vim.fn.fnameescape(lua_file))
  vim.cmd.write()
  wait(function() return vim.fn.readfile(lua_file)[1] == 'local value = 1' end, 'Lua was not formatted on save')
  print('PASS formatting: Python (Ruff) and Lua (StyLua) format on save')

  vim.cmd('qa!')
end)
vim.schedule(resume)
