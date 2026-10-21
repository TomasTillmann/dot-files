-- Run: env -u VIRTUAL_ENV nvim --headless '+luafile tests/git_view.lua'
-- Git lists in the one editing view (Space gg/gm/gb/gh/gf), the change lists' read-only previews, the history graph, side-by-side diffs without
-- a file panel or tab bar, q back, and files picked from a diff opening in the editing view. Real keys throughout.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 15e9
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message .. (vim.v.errmsg ~= '' and (': ' .. vim.v.errmsg) or ''))
    vim.defer_fn(resume, 20); coroutine.yield()
  end
end
local function settle(ms)
  local ready = vim.uv.hrtime() + (ms or 200) * 1e6
  wait(function() return vim.uv.hrtime() >= ready end, 'Events did not settle')
end
local function keys(input)
  wait(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Normal mode before ' .. input)
  vim.api.nvim_input(input)
  settle(120)
end

runner = coroutine.create(function()
  local ok, err = xpcall(function()
    vim.o.columns, vim.o.lines = 200, 50
    local root = vim.fn.tempname() .. '-git-view'
    vim.fn.mkdir(root .. '/src/app', 'p')
    root = assert(vim.uv.fs_realpath(root))
    local function git(...)
      local result = vim.system({ 'git', '-C', root, ... }, { text = true }):wait()
      assert(result.code == 0, result.stderr)
      return vim.trim(result.stdout)
    end
    local function commit(message)
      git('add', '.')
      git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', message)
      return git('rev-parse', 'HEAD')
    end
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
    vim.fn.writefile({ 'base' }, root .. '/base.txt')
    vim.fn.writefile({ 'local function model()', '  return 1', 'end' }, root .. '/src/app/model.lua')
    vim.fn.writefile({ 'first', 'second', 'git_view_token here' }, root .. '/target.txt')
    commit('Base')
    git('update-ref', 'refs/remotes/origin/main', 'HEAD')
    git('switch', '-qc', 'release')
    vim.fn.writefile({ 'release' }, root .. '/release.txt')
    commit('Release work')
    -- A side branch off release, so the history graph forks.
    git('switch', '-qc', 'side')
    vim.fn.writefile({ 'side' }, root .. '/side.txt')
    commit('Side work')
    git('switch', '-q', 'release')
    git('switch', '-qc', 'feature')
    vim.fn.writefile({ 'feature' }, root .. '/feature.txt')
    vim.fn.writefile({ 'local function model()', '  return 2', 'end' }, root .. '/src/app/model.lua')
    local feature = commit('Feature work')
    local head = feature
    -- Uncommitted: a modified file and an untracked one.
    vim.fn.writefile({ 'base changed' }, root .. '/base.txt')
    vim.fn.writefile({ 'brand new' }, root .. '/new.txt')
    vim.cmd.cd(vim.fn.fnameescape(root))
    vim.cmd.edit(vim.fn.fnameescape(root .. '/target.txt'))
    local editor, target = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()

    local gv = require('git_view')
    local pane = require('preview_pane')
    local function lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
    local function row_of(pattern)
      for row, line in ipairs(lines()) do if line:find(pattern) then return row end end
    end
    local function preview()
      local win = pane.win(vim.api.nvim_get_current_win())
      return win and vim.api.nvim_win_get_buf(win), win
    end
    local function preview_has(text)
      wait(function()
        local buf = preview()
        return buf and table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'):find(text, 1, true)
      end, 'Preview did not show ' .. text)
    end
    local function view() return require('diffview.lib').get_current_view() end
    local function diff_ready(path)
      wait(function()
        local v = view()
        return v and v.ready and v.cur_entry and v.cur_entry.path == path and v.cur_entry.opened
      end, 'Diff of ' .. path .. ' did not open')
      settle()
      local v = view()
      assert(#vim.api.nvim_list_tabpages() == 2 and vim.o.showtabline == 0, 'Diff should be one hidden tab')
      assert(not v.panel:is_open(), 'Diffview file panel is open')
      assert(vim.api.nvim_get_current_win() == v.cur_layout.b.id, 'Cursor is not in the right-hand diff pane')
      return v
    end
    local function in_list(title)
      wait(function() return vim.b.git_view and lines()[1]:find(title, 1, true) end, 'List ' .. title .. ' not shown')
      assert(vim.api.nvim_get_current_win() == editor, 'List is not in the editing window')
      assert(#vim.api.nvim_list_tabpages() == 1, 'List should leave a single tab')
    end
    local function goto_row(pattern)
      local row = assert(row_of(pattern), 'No row matching ' .. pattern .. ' in ' .. table.concat(lines(), '|'))
      vim.api.nvim_win_set_cursor(0, { row, 0 })
      settle(150)
    end

    -- Space gg: the current changes fill the view; the change under the cursor previews read-only on the right.
    keys(' gg')
    in_list('Current changes')
    assert(row_of('M .*base%.txt') and row_of('%? .*new%.txt') and not row_of('model%.lua'), 'Current changes: ' .. table.concat(lines(), '|'))
    local item = lines()[vim.fn.line('.')]
    assert(item:find('base%.txt'), 'Cursor should start on the first file: ' .. item)
    preview_has('+base changed')
    local preview_buf, preview_win = preview()
    assert(not vim.bo[preview_buf].modifiable, 'Preview is modifiable')
    assert(math.abs(vim.api.nvim_win_get_width(preview_win) - 120) <= 2, 'Preview is not 60% wide: ' .. vim.api.nvim_win_get_width(preview_win))
    keys('j')
    preview_has('+brand new')
    keys('l')
    assert(vim.api.nvim_get_current_win() == preview_win, 'l did not move into the preview')
    keys('q')
    assert(vim.api.nvim_get_current_win() == editor, 'q in the preview did not return to the list')

    -- Enter: the side-by-side diff alone, q back to the list on that file.
    goto_row('base%.txt')
    keys('<CR>')
    diff_ready('base.txt')
    keys('q')
    in_list('Current changes')
    assert(lines()[vim.fn.line('.')]:find('base%.txt'), 'q did not return to the diffed file')
    assert(preview(), 'Preview gone after returning from the diff')

    -- Space gg in the list goes back to the file.
    keys(' gg')
    wait(function() return vim.api.nvim_get_current_buf() == target end, 'Space gg in the list did not go back')
    assert(not pane.win(editor), 'Preview left behind next to the file')

    -- Telescope from a diff: the diff closes and the file opens in the one editing view.
    local state = require('telescope.actions.state')
    keys(' gg'); in_list('Current changes'); goto_row('base%.txt'); keys('<CR>'); diff_ready('base.txt')
    keys(' sg')
    wait(function() return vim.bo.filetype == 'TelescopePrompt' end, 'Space sg did not open a picker')
    vim.api.nvim_input('git_view_token')
    wait(function()
      local picker = state.get_current_picker(vim.api.nvim_get_current_buf())
      local count = 0
      if picker and picker.manager then for _ in picker.manager:iter() do count = count + 1 end end
      return count == 1 and state.get_selected_entry() ~= nil
    end, 'Space sg did not find the token')
    vim.api.nvim_input('<CR>')
    wait(function() return vim.api.nvim_get_current_buf() == target and vim.fn.line('.') == 3 end, 'Picked file did not open')
    settle()
    assert(#vim.api.nvim_list_tabpages() == 1 and vim.api.nvim_get_current_win() == editor, 'File did not open in the editing view')

    -- Space e from a diff: the tree replaces it, on the diffed file.
    keys(' gg'); in_list('Current changes'); goto_row('base%.txt'); keys('<CR>'); diff_ready('base.txt')
    keys(' e')
    wait(function() return vim.bo.filetype == 'neo-tree' end, 'Space e from a diff did not open the tree')
    assert(#vim.api.nvim_list_tabpages() == 1 and vim.api.nvim_get_current_win() == editor, 'Tree not in the editing view')
    wait(function() return vim.api.nvim_get_current_line():find('base.txt', 1, true) end, 'Tree did not reveal the diffed file')

    -- Space gm: changes since leaving main, committed and uncommitted; the tree list q's back to the tree.
    keys(' gm')
    in_list('Changes against main')
    for _, pattern in ipairs({ 'release%.txt', 'feature%.txt', 'model%.lua', 'base%.txt' }) do assert(row_of(pattern), 'Against main lacks ' .. pattern) end
    assert(not row_of('new%.txt'), 'Against main lists an untracked file')
    goto_row('model%.lua')
    preview_has('+  return 2')
    keys('<CR>')
    local v = diff_ready('src/app/model.lua')
    assert(v.rev_arg == 'origin/main...HEAD', 'Unexpected comparison ' .. tostring(v.rev_arg))
    keys('q')
    in_list('Changes against main')
    keys('q')
    wait(function() return vim.bo.filetype == 'neo-tree' end, 'q did not go back to the tree')

    -- Space gb: a picked branch, with the picker's Git actions disabled.
    vim.api.nvim_set_current_buf(target)
    keys(' gb')
    wait(function() return vim.bo.filetype == 'TelescopePrompt' end, 'Branch picker did not open')
    vim.api.nvim_input('<C-r>')
    vim.api.nvim_input('release')
    wait(function()
      local picker = state.get_current_picker(vim.api.nvim_get_current_buf())
      local entry = picker and picker:get_selection()
      return entry and entry.value == 'release'
    end, 'Picker did not select release')
    vim.api.nvim_input('<CR>')
    in_list('Changes against release')
    assert(row_of('feature%.txt') and not row_of('release%.txt'), 'Release comparison list: ' .. table.concat(lines(), '|'))
    assert(git('rev-parse', 'HEAD') == head and git('branch', '--show-current') == 'feature', 'Picker changed the repository')

    -- Space gh: every branch as a commit graph, full width without preview, starting on HEAD; a toggles to this branch.
    keys(' gh')
    in_list('History of all branches')
    local history = table.concat(lines(), '\n')
    assert(row_of('%(feature%) Feature work') and row_of('%(side%) Side work') and row_of('Release work') and row_of('Base'), 'History: ' .. history)
    assert(history:find('●', 1, true) and history:find('╱', 1, true), 'History has no graph: ' .. history)
    assert(lines()[vim.fn.line('.')]:find('Feature work', 1, true), 'History did not start on HEAD: ' .. vim.api.nvim_get_current_line())
    settle(150)
    assert(not pane.win(editor) and #vim.api.nvim_tabpage_list_wins(0) == 1, 'History shows a preview')
    local graph_only = 0
    for row, line in ipairs(lines()) do
      if row > 1 and not line:find('^%x+  %d') then graph_only = graph_only + 1 end
    end
    assert(graph_only > 0, 'Expected rows that only draw branch lines: ' .. history)
    keys('gg')
    for _ = 1, #lines() do
      assert(vim.fn.line('.') == 1 or vim.api.nvim_get_current_line():find('^%x+  %d'), 'j stopped on a graph-only row: ' .. vim.api.nvim_get_current_line())
      keys('j')
    end
    keys('gg'); goto_row('Feature work')
    keys('a')
    in_list('History of feature')
    assert(lines()[2]:find('Feature work', 1, true) and not row_of('Side work'), 'Current-branch history: ' .. table.concat(lines(), '|'))
    keys('<CR>')
    in_list('Feature work')
    assert(row_of('feature%.txt') and row_of('model%.lua') and not row_of('base%.txt'), 'Commit files: ' .. table.concat(lines(), '|'))
    goto_row('model%.lua')
    preview_has('+  return 2')
    keys('<CR>')
    v = diff_ready('src/app/model.lua')
    assert(v.rev_arg and v.rev_arg:find(feature, 1, true), 'Commit diff compares ' .. tostring(v.rev_arg))
    keys('q'); in_list('Feature work')
    keys('q'); in_list('History of feature')
    keys('a'); in_list('History of all branches')
    keys('q')
    wait(function() return vim.api.nvim_get_current_buf() == target end, 'q from the history did not return to the file')

    -- Space gf: the current file's history; Enter diffs that file in the commit.
    vim.cmd.edit(vim.fn.fnameescape(root .. '/src/app/model.lua'))
    keys(' gf')
    in_list('History of src/app/model.lua')
    assert(lines()[2]:find('Feature work', 1, true) and lines()[3]:find('Base', 1, true) and #lines() == 3, 'File history: ' .. table.concat(lines(), '|'))
    keys('<CR>')
    diff_ready('src/app/model.lua')
    keys('q'); in_list('History of src/app/model.lua')
    keys('q')
    wait(function() return vim.api.nvim_buf_get_name(0) == root .. '/src/app/model.lua' end, 'q did not return to model.lua')

    assert(vim.v.errmsg == '', vim.v.errmsg)
    vim.fn.delete(root, 'rf')
    print('PASS git view: Space gg/gm/gb/gh/gf lists full view, 60% read-only change previews, branch graph history without preview, diffs without panel or tabs, q back, picks from diffs open in place')
  end, debug.traceback)
  if not ok then vim.api.nvim_err_writeln(err) end
  vim.cmd(ok and 'qa!' or 'cquit 1')
end)

vim.schedule(resume)
