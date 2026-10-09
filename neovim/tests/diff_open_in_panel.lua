-- Run: env -u VIRTUAL_ENV nvim --headless '+luafile tests/diff_open_in_panel.lua'
-- Files picked in Telescope from a Git diff tab open in the Panel tab, leaving the diff untouched.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 15000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message)
    vim.defer_fn(resume, 25); coroutine.yield()
  end
end
local function settle()
  local ready = vim.uv.hrtime() + 300000000
  wait(function() return vim.uv.hrtime() >= ready end, 'Window events did not settle')
end

runner = coroutine.create(function()
  local ok, err = xpcall(function()
    vim.o.columns, vim.o.lines = 160, 50
    local state = require('telescope.actions.state')
    local root = vim.fn.tempname() .. '-panel-open'
    vim.fn.mkdir(root, 'p')
    root = assert(vim.uv.fs_realpath(root))
    local function git(...)
      local result = vim.system({ 'git', '-C', root, ... }, { text = true }):wait()
      assert(result.code == 0, result.stderr)
    end
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
    vim.fn.writefile({ 'changed before' }, root .. '/changed.txt')
    vim.fn.writefile({ 'first', 'second', 'panel_open_token here' }, root .. '/target.txt')
    git('add', '.')
    git('-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Fixture')
    vim.fn.writefile({ 'changed after' }, root .. '/changed.txt')
    vim.cmd.cd(vim.fn.fnameescape(root))
    local target = root .. '/target.txt'

    local function picker()
      if vim.bo.filetype ~= 'TelescopePrompt' then return nil end
      local found, current = pcall(state.get_current_picker, vim.api.nvim_get_current_buf())
      return found and current or nil
    end
    local function rows(current)
      local found = {}
      for entry in current.manager:iter() do found[#found + 1] = entry end
      return found
    end
    -- Real keys: open the picker, type, wait for a single result, press Enter.
    local function pick(keys, text)
      vim.api.nvim_input('<Esc>')
      wait(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Normal mode')
      vim.api.nvim_input(keys)
      wait(function() return picker() and vim.api.nvim_get_mode().mode == 'i' end, keys .. ' did not open a picker')
      local current = picker()
      if text then vim.api.nvim_input(text) end
      wait(function() return current.manager and #rows(current) == 1 and state.get_selected_entry() ~= nil end, keys .. ' did not find one result')
      vim.api.nvim_input('<CR>')
      wait(function() return not vim.api.nvim_buf_is_valid(current.prompt_bufnr) end, keys .. ' did not close')
      settle()
    end
    local function diff_tab(index)
      vim.api.nvim_feedkeys(tostring(index), 'xt', false)
      local view = require('diffview.lib').get_current_view()
      wait(function() return view.ready and view.cur_entry and view.cur_entry.opened end, 'Diff view did not load')
      settle()
      local wins = {}
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do wins[win] = vim.api.nvim_win_get_buf(win) end
      return view, wins
    end
    local function assert_untouched(tab, wins, message)
      local now = vim.api.nvim_tabpage_list_wins(tab)
      assert(#now == vim.tbl_count(wins), message .. ': diff tab gained or lost windows')
      for _, win in ipairs(now) do assert(wins[win] == vim.api.nvim_win_get_buf(win), message .. ': diff tab buffer replaced') end
    end
    local function assert_opened_in(tab, line, message)
      assert(vim.api.nvim_get_current_tabpage() == tab, message .. ': did not switch to the Panel tab')
      assert(vim.api.nvim_buf_get_name(0) == target, message .. ': opened ' .. vim.api.nvim_buf_get_name(0))
      assert(not line or vim.api.nvim_win_get_cursor(0)[1] == line, message .. ': wrong line ' .. vim.api.nvim_win_get_cursor(0)[1])
      assert(vim.api.nvim_win_get_config(0).relative == '' and vim.bo.filetype ~= 'neo-tree', message .. ': not an editing window')
    end

    require('tabline').open_workspace(root)
    local tabs = vim.api.nvim_list_tabpages()
    assert(#tabs == 3 and vim.t[tabs[1]].workspace_title == 'Panel', 'Workspace tabs')
    local editor
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabs[1])) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'neo-tree' then editor = win end
    end

    -- Space sg from a diff pane in Current Changes.
    local view, wins = diff_tab(2)
    assert(vim.wo.diff, 'Focus is not in a diff pane')
    pick(' sg', 'panel_open_token')
    assert_opened_in(tabs[1], 3, 'Space sg from Current Changes')
    assert(vim.api.nvim_get_current_win() == editor, 'Space sg did not reuse the Panel editing window')
    assert_untouched(tabs[2], wins, 'Space sg')
    assert(#vim.api.nvim_list_tabpages() == 3, 'Space sg created a tab')

    -- Space sf from the file panel in Current Changes, with Panel showing only the tree.
    vim.api.nvim_win_close(editor, true)
    vim.cmd('Neotree filesystem left')
    view, wins = diff_tab(2)
    vim.cmd('DiffviewFocusFiles')
    assert(vim.bo.filetype == 'DiffviewFiles', 'Focus is not in the file panel')
    pick(' sf', 'target.txt')
    assert_opened_in(tabs[1], nil, 'Space sf from the file panel') -- File search keeps the buffer's last position.
    assert_untouched(tabs[2], wins, 'Space sf')

    -- Recent files from the branch comparison tab.
    vim.cmd.edit(vim.fn.fnameescape(root .. '/changed.txt'))
    view, wins = diff_tab(3)
    pick('  ', 'target')
    assert_opened_in(tabs[1], 3, 'Space Space from Changes against main')
    assert_untouched(tabs[3], wins, 'Space Space')

    -- Searching the current diff buffer stays in the diff pane.
    view, wins = diff_tab(2)
    local pane = view.cur_layout.b.id
    vim.api.nvim_set_current_win(pane)
    wait(function() return vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == 'changed after' end, 'Working-tree pane did not load')
    pick(' ss', 'changed after')
    assert(vim.api.nvim_get_current_tabpage() == tabs[2] and vim.api.nvim_get_current_win() == pane, 'Space ss left the diff pane')
    assert_untouched(tabs[2], wins, 'Space ss')

    -- Without a Panel tab, the first ordinary tab receives the file.
    vim.t[tabs[1]].workspace_title = nil
    view, wins = diff_tab(2)
    pick(' sg', 'panel_open_token')
    assert_opened_in(tabs[1], 3, 'Space sg without a Panel tab')
    assert_untouched(tabs[2], wins, 'No Panel')

    -- Without any ordinary tab, a new Panel tab is created in front.
    vim.cmd('tabnext 1 | tabclose')
    view, wins = diff_tab(1)
    local diff = vim.api.nvim_get_current_tabpage()
    pick(' sg', 'panel_open_token')
    local panel = vim.api.nvim_list_tabpages()[1]
    assert(panel ~= diff and vim.t[panel].workspace_title == 'Panel', 'No new Panel tab in front')
    assert_opened_in(panel, 3, 'Space sg with only diff tabs')
    assert_untouched(diff, wins, 'New Panel')

    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      if vim.t[tab].diffview_title then vim.api.nvim_set_current_tabpage(tab); settle(); vim.cmd('DiffviewClose') end
    end
    vim.fn.delete(root, 'rf')
    print('PASS diff open in Panel: grep/files/recent from diff panes and file panel, Panel window reuse, tree-only Panel, current-buffer search, fallbacks')
  end, debug.traceback)
  if not ok then vim.api.nvim_err_writeln(err) end
  vim.cmd(ok and 'qa!' or 'cquit 1')
end)

vim.schedule(resume)
