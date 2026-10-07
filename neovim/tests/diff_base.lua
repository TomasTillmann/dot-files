-- Run: nvim --headless '+luafile tests/diff_base.lua'
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
  vim.o.columns, vim.o.lines = 160, 50
  local root = vim.fn.tempname() .. '-diff-base'
  vim.fn.mkdir(root, 'p')
  local function git(...)
    local args = { 'git', '-C', root }; vim.list_extend(args, { ... })
    local result = vim.system(args, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  local function commit(name, message)
    vim.fn.writefile({ message }, root .. '/' .. name)
    git('add', '.')
    git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', message)
  end
  git('init', '-q', '-b', 'main')
  git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
  commit('base.txt', 'Base')
  git('update-ref', 'refs/remotes/origin/main', 'HEAD')
  git('switch', '-qc', 'release')
  commit('release.txt', 'Release work')
  git('switch', '-qc', 'feature')
  commit('feature.txt', 'Feature work')
  local head = git('rev-parse', 'HEAD')
  vim.cmd.cd(root)

  local function current() return require('diffview.lib').get_current_view() end
  local function prompt_open() return vim.bo.filetype == 'TelescopePrompt' end
  local function choose(branch)
    wait(prompt_open, 'Branch picker did not open')
    vim.api.nvim_input('<C-r>') -- Disabled: must not rebase.
    vim.api.nvim_input(branch)
    wait(function()
      local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
      local entry = picker and picker:get_selection()
      return entry and entry.value == branch
    end, 'Picker did not select ' .. branch)
    vim.api.nvim_input('<CR>')
  end

  -- Clicking the comparison section replaces that tab's comparison in place.
  vim.cmd('tabnew')
  vim.cmd('DiffviewOpen origin/main...HEAD --imply-local')
  wait(function() local view = current(); return view and view.ready and view.files:len() == 2 end, 'Open main comparison')
  vim.cmd('tabnew')
  vim.cmd('tabprevious')
  local index, tab_count = vim.fn.tabpagenr(), #vim.api.nvim_list_tabpages()
  assert(vim.t.diffview_title == 'Changes against main')
  local panel = current().panel
  local lines = vim.api.nvim_buf_get_lines(panel.bufid, 0, -1, false)
  local header = vim.fn.index(lines, 'Showing changes for:')
  assert(header >= 0, 'Missing comparison section: ' .. table.concat(lines, '|'))
  local row = header + 2
  assert(lines[row] == 'origin/main...HEAD', 'Unexpected comparison line: ' .. tostring(lines[row]))
  vim.cmd('wincmd l') -- Click from the diff pane, not the focused panel.
  local pos = vim.fn.screenpos(panel.winid, row, 1)
  vim.api.nvim_input_mouse('left', 'press', '', 0, pos.row - 1, pos.col - 1)
  vim.api.nvim_input_mouse('left', 'release', '', 0, pos.row - 1, pos.col - 1)
  choose('release')
  wait(function() local view = current(); return view and view.rev_arg == 'release...HEAD' and view.ready and view.files:len() == 1 end, 'Comparison did not switch to release')
  assert(current().files.working[1].path == 'feature.txt', 'Release comparison should only show feature work')
  assert(vim.t.diffview_title == 'Changes against release')
  assert(vim.fn.tabpagenr() == index and #vim.api.nvim_list_tabpages() == tab_count, 'Switch changed tab position or count')
  assert(git('rev-parse', 'HEAD') == head and git('branch', '--show-current') == 'feature', 'Picker changed the repository')

  -- Clicking file entries keeps the normal behavior.
  local file_row = vim.fn.match(vim.api.nvim_buf_get_lines(current().panel.bufid, 0, -1, false), 'feature\\.txt') + 1
  assert(file_row > 0, 'Missing file entry')
  pos = vim.fn.screenpos(current().panel.winid, file_row, 1)
  vim.api.nvim_input_mouse('left', 'press', '', 0, pos.row - 1, pos.col - 1)
  vim.api.nvim_input_mouse('left', 'release', '', 0, pos.row - 1, pos.col - 1)
  wait(function() return vim.api.nvim_get_current_win() == current().panel.winid end, 'File panel click did not focus panel')
  assert(not prompt_open(), 'File entry click opened the branch picker')

  -- Space g b from a non-comparison tab opens a new comparison.
  vim.cmd('tablast')
  tab_count = #vim.api.nvim_list_tabpages()
  vim.api.nvim_input(' gb')
  choose('main')
  wait(function() local view = current(); return view and view.rev_arg == 'main...HEAD' and view.ready end, 'Space g b did not open a comparison')
  assert(#vim.api.nvim_list_tabpages() == tab_count + 1, 'Space g b should add a comparison tab')
  assert(vim.t.diffview_title == 'Changes against main')

  vim.cmd('DiffviewClose')
  vim.fn.delete(root, 'rf')
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('PASS branch picker: panel click and Space g b, in-place switch, tab position/title, file clicks unchanged, repo untouched')
  vim.cmd('qa!')
end)
vim.schedule(resume)
