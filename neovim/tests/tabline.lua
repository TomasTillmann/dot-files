-- Run: nvim --headless '+luafile tests/tabline.lua'
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function tick()
  vim.defer_fn(resume, 30)
  coroutine.yield()
end
local function click(row, col)
  vim.api.nvim_input_mouse('left', 'press', '', 0, row, col)
  tick()
  vim.api.nvim_input_mouse('left', 'release', '', 0, row, col)
  tick()
end
runner = coroutine.create(function()
  vim.o.columns, vim.o.lines = 120, 30
  vim.cmd('enew')
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_name(0, 'percent%file.txt')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved' })
  local first = vim.api.nvim_get_current_tabpage()
  local render = require('tabline').render
  assert(render():find('percent%%file.txt +', 1, true), 'Filename escaping or modified marker missing')
  vim.cmd('tabnew')
  vim.t.diffview_title = 'Changes'
  local line = render()
  assert(line:find('%2T 2 Changes', 1, true), 'Missing readable tab label/click target')
  assert(line:find('%999X', 1, true), 'Missing close target')
  vim.cmd('vnew')
  assert(render():find('Changes', 1, true), 'Label changed when focus moved')
  vim.cmd('redraw')
  vim.api.nvim_input('<Esc>')
  tick()
  click(0, 3)
  assert(vim.api.nvim_get_current_tabpage() == first, 'Single click did not select first tab')
  click(0, 3)
  assert(#vim.api.nvim_list_tabpages() == 2, 'Double-click on a tab created an empty tab')
  click(0, 90)
  click(0, 90)
  assert(#vim.api.nvim_list_tabpages() == 2, 'Double-click on empty tabline space created a tab')

  -- Preserve word selection, including the first screen row when the tabline is hidden.
  vim.api.nvim_set_current_tabpage(first)
  for _, showtabline in ipairs({ 1, 0 }) do
    vim.o.showtabline = showtabline
    vim.cmd('redraw')
    local pos = vim.fn.screenpos(0, 1, 3)
    click(pos.row - 1, pos.col - 1)
    click(pos.row - 1, pos.col - 1)
    assert(vim.api.nvim_get_mode().mode == 'v', 'Buffer double-click stopped selecting words')
    assert(table.concat(vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'))) == 'unsaved', 'Double-click selected the wrong text')
    vim.api.nvim_input('<Esc>')
    tick()
  end
  vim.o.showtabline = 1
  require('neo-tree.command').execute({ action = 'focus', source = 'filesystem', position = 'left' })
  tick()
  assert(vim.bo.filetype == 'neo-tree', 'File tree did not gain focus')
  vim.cmd('redraw')
  click(0, 3)
  click(0, 3)
  assert(#vim.api.nvim_list_tabpages() == 2, 'Double-click created a tab while the file tree was focused')
  vim.cmd('tabnext 2')
  vim.cmd('tabclose')
  assert(vim.api.nvim_get_current_tabpage() == first and not render():find('Changes', 1, true))
  print('PASS tab labels, single-click switching, no double-click tabs, word selection, tree focus, close')
  vim.cmd('qa!')
end)
vim.schedule(resume)
