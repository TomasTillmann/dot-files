-- Run: nvim --headless '+luafile tests/side_panel.lua'
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
local function count(filetype)
  local n = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == filetype then n = n + 1 end
  end
  return n
end
local function pause(ms) vim.defer_fn(resume, ms); coroutine.yield() end
local function space_b(filetype, expected, where)
  pause(200) -- Let panels finish mounting, as they would before a person types.
  vim.api.nvim_input(' b')
  wait(function() return count(filetype) == expected end, ('Space b from %s should leave %d %s window(s)'):format(where, expected, filetype))
  assert(count('neo-tree') == 0 or filetype == 'neo-tree', 'Space b opened the file tree from ' .. where)
end
runner = coroutine.create(function()
  vim.o.columns, vim.o.lines = 160, 50
  local root = vim.fn.tempname() .. '-side-panel'
  vim.fn.mkdir(root, 'p')
  local function git(...)
    local args = { 'git', '-C', root }; vim.list_extend(args, { ... })
    local result = vim.system(args, { text = true }):wait()
    assert(result.code == 0, result.stderr)
  end
  git('init', '-q')
  git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
  vim.fn.writefile({ 'one' }, root .. '/a.txt')
  git('add', '.')
  git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Fixture')
  vim.cmd.cd(root)
  vim.cmd.edit('a.txt')

  -- Editing tab: toggles the file tree from the editor and from inside the tree.
  space_b('neo-tree', 1, 'editor')
  assert(vim.bo.filetype ~= 'neo-tree', 'Opening the tree should keep the cursor in the editor')
  vim.cmd('wincmd h')
  space_b('neo-tree', 0, 'inside the tree')

  -- Git tab without changes: the diff windows hold placeholder buffers without Diffview mappings.
  vim.cmd('DiffviewOpen')
  wait(function() return count('DiffviewFiles') == 1 end, 'Diffview did not open')
  vim.cmd('wincmd l')
  assert(vim.api.nvim_buf_get_name(0) == 'diffview://null', 'Expected an empty-diff placeholder window')
  space_b('DiffviewFiles', 0, 'an empty diff window')
  space_b('DiffviewFiles', 1, 'an empty diff window with the panel closed')
  vim.cmd('DiffviewClose')

  -- Git tab with changes, from a diff side and from the panel.
  vim.fn.writefile({ 'two' }, root .. '/a.txt')
  vim.cmd('DiffviewOpen')
  wait(function() return count('DiffviewFiles') == 1 and vim.bo.filetype ~= 'DiffviewFiles' or vim.cmd('wincmd l') end, 'Diffview with changes did not open')
  space_b('DiffviewFiles', 0, 'a diff side')
  space_b('DiffviewFiles', 1, 'a diff side with the panel closed')
  assert(vim.bo.filetype == 'DiffviewFiles', 'Reopened Git panel should be focused')
  space_b('DiffviewFiles', 0, 'the Git panel')

  -- A file tree opened inside a Git tab is the left panel there, so it closes first.
  space_b('DiffviewFiles', 1, 'a diff side')
  require('neo-tree.command').execute({ action = 'show', position = 'left' })
  wait(function() return count('neo-tree') == 1 end, 'Neo-tree did not open in the Git tab')
  space_b('neo-tree', 0, 'a Git tab with the file tree open')
  assert(count('DiffviewFiles') == 1, 'Closing the file tree should keep the Git panel')
  vim.cmd('DiffviewClose')

  print('PASS side panel: Space b toggles the file tree and Git panels from any window, including empty diffs')
  vim.cmd('qa!')
end)
vim.schedule(resume)
