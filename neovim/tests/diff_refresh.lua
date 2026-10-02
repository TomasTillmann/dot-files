-- Run: nvim --headless '+luafile tests/diff_refresh.lua'
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 12000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message .. ': ' .. vim.v.errmsg)
    vim.defer_fn(resume, 20); coroutine.yield()
  end
end
runner = coroutine.create(function()
  local root = vim.fn.tempname() .. '-diff-refresh'
  vim.fn.mkdir(root .. '/nested', 'p')
  local function git(...)
    local args = { 'git', '-C', root }; vim.list_extend(args, { ... })
    local result = vim.system(args, { text = true }):wait()
    assert(result.code == 0, result.stderr)
  end
  local function write(name, text) vim.fn.writefile({ text }, root .. '/' .. name) end
  git('init', '-q'); git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
  write('nested/a.txt', 'original'); git('add', '.')
  git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Fixture')
  git('update-ref', 'refs/remotes/origin/main', 'HEAD')
  vim.cmd.cd(root)
  for _, command in ipairs({ 'DiffviewOpen', 'DiffviewOpen origin/main...HEAD --imply-local' }) do
    write('nested/a.txt', 'initial change')
    vim.fn.delete(root .. '/new.txt')
    vim.cmd(command)
    local view = require('diffview.lib').get_current_view()
    wait(function() return view.cur_entry and view.cur_entry.opened end, 'Open view')
    local buf = vim.fn.bufnr(root .. '/nested/a.txt')
    assert(buf > 0 and vim.o.autoread)
    local tab = vim.api.nvim_get_current_tabpage()
    local refreshes = 0
    local update = view.update_files
    view.update_files = function(self, ...) refreshes = refreshes + 1; return update(self, ...) end
    local idle_until = vim.uv.hrtime() + 1000000000
    wait(function() return vim.uv.hrtime() >= idle_until end, 'Idle check')
    assert(refreshes == 0, 'Idle view polled Git')
    write('nested/a.txt', 'external agent changed contents')
    wait(function() return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'external agent changed contents' end, 'Reload external edit')
    local settle = vim.uv.hrtime() + 1500000000
    wait(function() return vim.uv.hrtime() >= settle end, 'Settle filesystem events')
    local before_idle = refreshes
    local idle = vim.uv.hrtime() + 2000000000
    wait(function() return vim.uv.hrtime() >= idle end, 'Check settled idle')
    assert(refreshes == before_idle, 'Refresh triggered a filesystem feedback loop')
    write('new.txt', 'new agent file')
    if command ~= 'DiffviewOpen' then git('add', 'new.txt') end -- Branch comparison excludes untracked by default.
    wait(function() return view.files:len() == 2 end, 'Discover new file')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'my unsaved edit' })
    write('nested/a.txt', 'another external edit')
    local until_time = vim.uv.hrtime() + 2500000000
    wait(function() return vim.uv.hrtime() >= until_time end, 'Wait for refresh')
    assert(vim.bo[buf].modified and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'my unsaved edit', 'Unsaved edits overwritten')
    assert(vim.api.nvim_get_current_tabpage() == tab, 'Refresh changed tabs')
    vim.bo[buf].modified = false -- Disposable fixture only.
    local state = view.auto_refresh
    vim.cmd('DiffviewClose')
    assert(state.timer:is_closing() and state.watcher:is_closing() and view.auto_refresh == nil, 'Timer leaked after close')
    git('reset', '-q', 'HEAD', '--', 'new.txt')
    vim.cmd('silent! bwipeout! ' .. buf)
  end
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('PASS live diff refresh: external file contents, new files, working/branch views, unsaved edit protection, timer cleanup')
  vim.cmd('qa!')
end)
vim.schedule(resume)
