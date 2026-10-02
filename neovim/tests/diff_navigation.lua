-- Run: nvim --headless '+luafile tests/diff_navigation.lua'
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 10000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message .. ': ' .. vim.v.errmsg)
    vim.defer_fn(resume, 10)
    coroutine.yield()
  end
end
runner = coroutine.create(function()
  vim.o.columns, vim.o.lines = 160, 50
  local next_mapping, previous_mapping = vim.fn.maparg('<C-j>', 'n'), vim.fn.maparg('<C-k>', 'n')
  local root = vim.fn.tempname() .. '-diff-navigation'
  vim.fn.mkdir(root, 'p')
  local function git(...)
    local args = { 'git', '-C', root }; vim.list_extend(args, { ... })
    local result = vim.system(args, { text = true }):wait()
    assert(result.code == 0, result.stderr)
  end
  git('init', '-q')
  git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
  git('config', 'core.filemode', 'true')
  local lines = {}
  for i = 1, 30 do lines[i] = 'original ' .. i end
  for _, name in ipairs({ 'a.txt', 'b.txt', 'c.txt' }) do vim.fn.writefile(lines, root .. '/' .. name) end
  git('add', '.')
  git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Fixture')
  local a, c = vim.deepcopy(lines), vim.deepcopy(lines)
  a[5], a[20] = 'changed five', 'changed twenty'
  c[1], c[30] = 'changed first', 'changed last'
  vim.fn.writefile(a, root .. '/a.txt'); vim.fn.writefile(c, root .. '/c.txt')
  assert(vim.uv.fs_chmod(root .. '/b.txt', 493)) -- Mode-only change: no text hunks.
  vim.cmd.cd(root)
  vim.cmd('DiffviewOpen')
  local view = require('diffview.lib').get_current_view()
  wait(function() return view.cur_entry and view.cur_entry.opened and view.files:len() == 3 end, 'Load files')
  vim.api.nvim_set_current_win(view.cur_layout:get_main_win().id)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local function jump(key, file, line)
    vim.api.nvim_input(key)
    wait(function() return not view.navigating_hunks and view.cur_entry.path == file and vim.fn.line('.') == line end, key .. ' -> ' .. file .. ':' .. line)
  end
  jump('<C-j>', 'a.txt', 5)
  jump('<C-j>', 'a.txt', 20)
  jump('<C-j>', 'c.txt', 1)
  jump('<C-j>', 'c.txt', 30)
  jump('<C-j>', 'a.txt', 5)
  jump('<C-k>', 'c.txt', 30)
  jump('<C-k>', 'c.txt', 1)
  jump('<C-k>', 'a.txt', 20)
  assert(vim.fn.maparg('<Esc>', 'n', false, true).buffer == 0, 'Diffview overrides normal Escape behavior')
  local cursor, entry = vim.api.nvim_win_get_cursor(0), view.cur_entry
  vim.api.nvim_input('<Esc>')
  vim.defer_fn(resume, 150); coroutine.yield()
  assert(vim.deep_equal(cursor, vim.api.nvim_win_get_cursor(0)) and view.cur_entry == entry, 'Escape moved to another change')
  assert(vim.v.errmsg == '', vim.v.errmsg)
  vim.cmd('DiffviewClose')
  assert(vim.fn.maparg('<C-j>', 'n') == next_mapping, 'Next-change mapping leaked outside Diffview')
  assert(vim.fn.maparg('<C-k>', 'n') == previous_mapping, 'Previous-change mapping leaked outside Diffview')
  git('add', '.')
  git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Changed fixture')
  vim.cmd('DiffviewFileHistory')
  view = require('diffview.lib').get_current_view()
  wait(function() return view.cur_entry and view.cur_entry.opened and #view.panel.entries == 2 end, 'Load history')
  vim.api.nvim_set_current_win(view.cur_layout:get_main_win().id)
  vim.api.nvim_win_set_cursor(0, { 20, 0 })
  jump('<C-j>', 'c.txt', 1)
  jump('<C-k>', 'a.txt', 20)
  vim.cmd('DiffviewClose')
  print('PASS diff navigation: real keys, both directions, first/last-line hunks, cross-file wrap, mode-only file skipped, mappings cleaned up')
  vim.cmd('qa!')
end)
vim.schedule(resume)
