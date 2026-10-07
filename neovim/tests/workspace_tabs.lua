-- Run: nvim --headless '+luafile tests/workspace_tabs.lua'
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd('cquit 1') end
end
local function wait(predicate)
  local deadline = vim.uv.hrtime() + 10000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, 'Timed out waiting for event or changed file')
    vim.defer_fn(resume, 20); coroutine.yield()
  end
end
local function resize(columns)
  local resized, focus = false, vim.api.nvim_get_current_win()
  vim.api.nvim_create_autocmd('VimResized', { once = true, callback = function() resized = true end })
  vim.o.columns = columns
  wait(function() return resized end)
  assert(vim.api.nvim_get_current_win() == focus, 'Resize changed focus')
end
local function assert_balanced()
  local view = require('diffview.lib').get_current_view()
  local left, right = view.cur_layout.a.id, view.cur_layout.b.id
  assert(math.abs(vim.api.nvim_win_get_width(left) - vim.api.nvim_win_get_width(right)) <= 1, 'Diff panes have unequal widths')
  assert(vim.api.nvim_win_get_width(view.panel.winid) == 34, 'Resize changed sidebar width')
end
runner = coroutine.create(function()
  local ok, err = xpcall(function()
    vim.o.columns, vim.o.lines = 160, 50
    local root = vim.fn.tempname() .. ' workspace'
    vim.fn.mkdir(root, 'p')
    local function git(...)
      local result = vim.system({ 'git', '-C', root, ... }, { text = true }):wait()
      assert(result.code == 0, result.stderr)
    end
    for index = 1, 9 do
      assert(vim.fn.maparg(tostring(index), 'i') == '', 'Tab shortcut leaked into Insert mode')
    end
    local open = require('tabline').open_workspace
    open(root)
    assert(#vim.api.nvim_list_tabpages() == 1, 'Non-Git folder created tabs')
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
    vim.fn.writefile({ 'before' }, root .. '/file.txt')
    git('add', '.')
    git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Fixture')
    vim.fn.writefile({ 'after' }, root .. '/file.txt')
    for _, remote in ipairs({ false, true }) do
      if remote then git('update-ref', 'refs/remotes/origin/main', 'HEAD') end
      open(root)
      local tabs = vim.api.nvim_list_tabpages()
      assert(#tabs == 3 and vim.api.nvim_get_current_tabpage() == tabs[1], 'Startup tabs/focus')
      assert(vim.t[tabs[1]].workspace_title == 'Panel')
      assert(vim.t[tabs[2]].diffview_title == 'Current Changes')
      assert(vim.t[tabs[3]].diffview_title == 'Changes against main')
      for index = 2, 3 do
        vim.api.nvim_feedkeys(tostring(index), 'xt', false)
        assert(vim.api.nvim_get_current_tabpage() == tabs[index])
        local view = require('diffview.lib').get_current_view()
        -- Diff panes briefly show a placeholder buffer while loading, so check the window, not its filetype.
        assert(vim.api.nvim_get_current_win() ~= view.panel.winid, 'Tab shortcut left focus in side panel')
        wait(function() return view.ready and view.files:len() == 1 and view.cur_entry and view.cur_entry.opened end)
        assert(vim.bo.filetype ~= 'DiffviewFiles', 'Focus did not settle in a diff pane')
        assert(view.rev_arg == (index == 3 and ((remote and 'origin/main' or 'main') .. '...HEAD') or nil))
        for _, columns in ipairs({ 240, 100, 160 }) do
          resize(columns)
          assert_balanced()
        end
      end
      vim.api.nvim_feedkeys('1', 'xt', false)
      assert(vim.api.nvim_get_current_tabpage() == tabs[1] and vim.bo.filetype ~= 'neo-tree', '1 should focus editing buffer')
      local editing = vim.api.nvim_get_current_win()
      vim.cmd('vsplit | vertical resize 25')
      local narrow = vim.api.nvim_get_current_win()
      resize(240)
      local narrow_width = vim.api.nvim_win_get_width(narrow)
      assert(math.abs(narrow_width - vim.api.nvim_win_get_width(editing)) > 1, 'Resize equalized ordinary editing splits')
      for index = 2, 3 do
        vim.api.nvim_feedkeys(tostring(index), 'xt', false)
        assert_balanced()
      end
      vim.api.nvim_feedkeys('1', 'xt', false)
      assert(vim.api.nvim_win_get_width(narrow) == narrow_width, 'Tab entry equalized ordinary editing splits')
      vim.api.nvim_win_close(narrow, false)
      resize(160)
      vim.api.nvim_feedkeys('23', 'xt', false)
      assert(vim.api.nvim_get_current_tabpage() == tabs[3] and vim.bo.filetype ~= 'DiffviewFiles')
      vim.cmd('DiffviewFocusFiles')
      assert(vim.bo.filetype == 'DiffviewFiles')
      vim.api.nvim_feedkeys('2', 'xt', false)
      assert(vim.api.nvim_get_current_tabpage() == tabs[2] and vim.bo.filetype ~= 'DiffviewFiles', 'Switch from panel to buffer')
      vim.cmd('DiffviewFocusFiles')
      vim.api.nvim_feedkeys('3', 'xt', false)
      assert(vim.api.nvim_get_current_tabpage() == tabs[3] and vim.bo.filetype ~= 'DiffviewFiles', 'Consecutive switch from panel')
      vim.defer_fn(resume, 300); coroutine.yield()
      vim.cmd('tabnext 2'); vim.defer_fn(resume, 300); coroutine.yield(); vim.cmd('DiffviewClose')
      vim.api.nvim_feedkeys('2', 'xt', false)
      assert(vim.api.nvim_get_current_tabpage() == tabs[3], 'Tab positions after closing')
      vim.defer_fn(resume, 300); coroutine.yield()
      vim.cmd('DiffviewClose')
      vim.defer_fn(resume, 300); coroutine.yield()
    end
    git('branch', '-m', 'other')
    git('update-ref', '-d', 'refs/remotes/origin/main')
    open(root)
    assert(#vim.api.nvim_list_tabpages() == 2, 'Missing main should skip comparison')
    vim.cmd('tabnext 2'); vim.defer_fn(resume, 300); coroutine.yield(); vim.cmd('DiffviewClose')
    vim.cmd('Neotree close')
    vim.fn.delete(root, 'rf')
    print('PASS workspace tabs: non-Git, local/remote main, live diffs, equal widths on resize/tab entry, focus, numbered navigation, close, missing main')
  end, debug.traceback)
  if not ok then vim.api.nvim_err_writeln(err) end
  vim.cmd(ok and 'qa!' or 'cquit 1')
end)

vim.schedule(resume)
