-- Run: nvim --headless '+luafile tests/diff_branch_refresh.lua'
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
  local root = vim.fn.tempname() .. '-diff-branch-refresh'
  vim.fn.mkdir(root, 'p')
  local function git(...)
    local args = { 'git', '-C', root }; vim.list_extend(args, { ... })
    local result = vim.system(args, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  local function write(name, lines) vim.fn.writefile(lines, root .. '/' .. name) end
  local function commit(message)
    git('add', '.')
    git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', message)
  end
  git('init', '-q', '-b', 'main')
  git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
  local original = { 'imageName: rocky/grace-service', '', 'unchanged 3', 'unchanged 4', 'unchanged 5', 'unchanged 6', '', 'feature: original' }
  write('a-shared.txt', original)
  write('main-only.txt', { 'imageName: rocky/grace-service' })
  write('feature.txt', { 'original' }); commit('Base')
  git('update-ref', 'refs/remotes/origin/main', 'HEAD')
  git('switch', '-qc', 'feature')
  local feature = vim.deepcopy(original); feature[8] = 'feature: branch change'
  write('a-shared.txt', feature); write('feature.txt', { 'branch change' }); commit('Feature work')
  vim.cmd.cd(root)
  vim.cmd('DiffviewOpen origin/main...HEAD --imply-local --selected-file=a-shared.txt')
  local function current() return require('diffview.lib').get_current_view() end
  wait(function() local view = current(); return view and view.cur_entry and view.cur_entry.opened and view.files:len() == 2 end, 'Open branch view')
  local old_state = current().auto_refresh
  local tab_index, tab_count = vim.fn.tabpagenr(), #vim.api.nvim_list_tabpages()
  local local_buf = vim.fn.bufnr(root .. '/a-shared.txt')
  assert(local_buf > 0)

  -- Merge main while the view remains open: main-owned changes must disappear.
  git('switch', '-q', 'main')
  local main = vim.deepcopy(original); main[1] = 'imageName: grace-service'
  write('a-shared.txt', main); write('main-only.txt', { 'imageName: grace-service' }); commit('Remove rocky prefix on main')
  local main_hash = git('rev-parse', 'HEAD')
  git('update-ref', 'refs/remotes/origin/main', 'HEAD')
  git('switch', '-q', 'feature')
  git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'merge', '--no-edit', 'main')
  assert(git('merge-base', 'origin/main', 'HEAD') == main_hash)
  assert(git('diff', '--name-only', 'origin/main...HEAD') == 'a-shared.txt\nfeature.txt', 'Fixture includes unexpected branch changes')
  wait(function()
    local view = current()
    return view and view.left.commit == main_hash and view.files:len() == 2 and view.cur_entry and view.cur_entry.opened
  end, 'Branch comparison kept its old merge base after merging main')
  local view = current()
  assert(view.cur_entry.path == 'a-shared.txt', 'Refresh lost selected file')
  local left = view.cur_entry.layout.a.file
  wait(function() return left.bufnr and vim.api.nvim_buf_is_loaded(left.bufnr) end, 'Load updated left buffer')
  assert(vim.api.nvim_buf_get_lines(left.bufnr, 0, 1, false)[1] == 'imageName: grace-service', 'Same-path diff buffer still shows old main contents')
  assert(vim.api.nvim_buf_get_lines(local_buf, 0, 1, false)[1] == 'imageName: grace-service', 'Working buffer still shows pre-merge contents')
  assert(old_state.closed and old_state.git_watcher:is_closing(), 'Old Git watcher leaked on reopen')
  assert(vim.fn.tabpagenr() == tab_index and #vim.api.nvim_list_tabpages() == tab_count, 'Refresh changed tab position or count')

  -- Moving refs alone must also refresh; rebuilding the view must preserve edits.
  vim.cmd('tabonly') -- Also preserve tab count when the diff is the only remaining tab.
  tab_index, tab_count = 1, 1
  vim.api.nvim_buf_set_lines(local_buf, 7, 8, false, { 'feature: my unsaved edit' })
  local merged_head = git('rev-parse', 'HEAD')
  git('update-ref', 'refs/heads/main', merged_head)
  git('update-ref', 'refs/remotes/origin/main', merged_head)
  assert(git('diff', '--name-only', 'origin/main...HEAD') == '')
  wait(function() local updated = current(); return updated and updated.left.commit == merged_head and updated.files:len() == 0 end, 'Ref-only update did not refresh branch comparison')
  assert(vim.api.nvim_buf_is_valid(local_buf) and vim.bo[local_buf].modified, 'Refresh discarded unsaved local buffer')
  assert(vim.api.nvim_buf_get_lines(local_buf, 7, 8, false)[1] == 'feature: my unsaved edit', 'Refresh overwrote unsaved edits')
  assert(vim.fn.tabpagenr() == tab_index and #vim.api.nvim_list_tabpages() == tab_count, 'Ref refresh changed tab position or count')
  vim.bo[local_buf].modified = false -- Disposable fixture only.
  vim.cmd('DiffviewClose')
  vim.fn.delete(root, 'rf')
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('PASS branch diff refresh: main merge, same-path base contents, ref-only update, tab position, unsaved edits')
  vim.cmd('qa!')
end)
vim.schedule(resume)
