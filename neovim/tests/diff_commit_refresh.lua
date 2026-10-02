-- Run: nvim --headless '+luafile tests/diff_commit_refresh.lua'
-- A real shell commit in a disposable repo; no tab switch or manual refresh.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 10000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message .. ': ' .. vim.v.errmsg)
    vim.defer_fn(resume, 20); coroutine.yield()
  end
end
runner = coroutine.create(function()
  vim.o.columns, vim.o.lines = 160, 50
  local root = vim.fn.tempname() .. '-diff-commit-refresh'
  vim.fn.mkdir(root, 'p')
  local function git(...)
    local args = { 'git', '-C', root }; vim.list_extend(args, { ... })
    local result = vim.system(args, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  git('init', '-q', '-b', 'main')
  git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
  vim.fn.writefile({ 'original' }, root .. '/a.txt'); git('add', '.')
  git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Fixture')
  vim.fn.writefile({ 'staged change' }, root .. '/a.txt'); git('add', '.')
  vim.cmd.cd(root)
  require('lazy').load({ plugins = { 'diffview.nvim' } })
  assert(not require('diffview.config').get_config().watch_index, 'Index polling should be disabled')
  vim.cmd('DiffviewOpen')
  local view = require('diffview.lib').get_current_view()
  wait(function() return view.cur_entry and view.cur_entry.opened and #view.files.staged == 1 end, 'Open staged change')
  local tab = vim.api.nvim_get_current_tabpage()
  git('reset', '-q', 'HEAD', '--', 'a.txt')
  wait(function() return #view.files.staged == 0 and #view.files.working == 1 end, 'Index-only unstage event')
  git('add', 'a.txt')
  wait(function() return #view.files.staged == 1 and #view.files.working == 0 end, 'Index-only stage event')
  vim.api.nvim_input(' t')
  wait(function() return vim.bo.filetype == 'toggleterm' and vim.api.nvim_get_mode().mode == 't' end, 'Open popup terminal')
  local term = require('toggleterm.terminal').get(1)
  vim.api.nvim_chan_send(term.job_id, "git -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm 'Commit from popup' && printf 'COMMIT_DONE\\n'\n")
  wait(function()
    for _, line in ipairs(vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false)) do
      if vim.trim(line) == 'COMMIT_DONE' then return true end
    end
  end, 'Shell commit completed')
  assert(git('status', '--porcelain') == '', 'Fixture is not clean after commit')
  -- Let the event debounce expire while still typing in the shell.
  local settle = vim.uv.hrtime() + 1500000000
  wait(function() return vim.uv.hrtime() >= settle end, 'Settle commit events in terminal mode')
  assert(vim.api.nvim_get_current_win() == term.window and vim.api.nvim_get_mode().mode == 't', 'Refresh interrupted terminal input')
  vim.api.nvim_input('<Esc><Esc>')
  wait(function() return not term:is_open() and vim.api.nvim_get_mode().mode == 'n' end, 'double Escape hides popup terminal')
  assert(vim.api.nvim_get_current_tabpage() == tab, 'Terminal changed tabs')
  wait(function() return view.files:len() == 0 end, 'Current Changes still contains committed files')
  assert(vim.api.nvim_get_current_tabpage() == tab, 'Refresh changed tabs')
  local updates, update = 0, view.update_files
  view.update_files = function(self, ...) updates = updates + 1; return update(self, ...) end
  local idle = vim.uv.hrtime() + 2000000000
  wait(function() return vim.uv.hrtime() >= idle end, 'Idle refresh check')
  assert(updates == 0, 'Idle current view repeatedly refreshed')
  local state = view.auto_refresh
  vim.cmd('DiffviewClose')
  assert(state.git_watcher:is_closing(), 'Git watcher leaked after closing view')
  term:shutdown()
  vim.fn.delete(root, 'rf')
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('PASS current diff refresh: stage/unstage, popup commit, double Escape, no tab switch or polling')
  vim.cmd('qa!')
end)
vim.schedule(resume)
