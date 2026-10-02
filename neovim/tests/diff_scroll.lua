-- Run: nvim --headless '+luafile tests/diff_scroll.lua'
-- Exercise real mouse events; all buffers are disposable and unnamed.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 5000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message)
    vim.defer_fn(resume, 20)
    coroutine.yield()
  end
end
local function pause(ms)
  vim.defer_fn(resume, ms)
  coroutine.yield()
end
runner = coroutine.create(function()
  vim.o.columns, vim.o.lines = 160, 50
  vim.cmd('enew')
  local lines = {}
  for i = 1, 300 do lines[i] = ('line %03d '):format(i) .. string.rep('x', 250) end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  local left = vim.api.nvim_get_current_win()
  vim.cmd('diffthis')
  vim.cmd('vnew')
  lines[150] = 'changed line'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  local right = vim.api.nvim_get_current_win()
  vim.cmd('diffthis')
  vim.cmd('topleft 25vnew')
  local sidebar = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  local function top(win) return vim.fn.line('w0', win) end
  local function column(win) return vim.api.nvim_win_call(win, function() return vim.fn.winsaveview().leftcol end) end
  local function wheel(win, direction)
    vim.cmd('redraw')
    local pos = vim.api.nvim_win_get_position(win)
    vim.api.nvim_input_mouse('wheel', direction, '', 0, pos[1] + 5, pos[2] + 10)
  end
  vim.api.nvim_input('<Esc>')
  wait(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Normal mode')
  for _, target in ipairs({ left, right }) do
    vim.api.nvim_set_current_win(sidebar)
    local before = top(left)
    wheel(target, 'down')
    wait(function() return top(left) > before and top(right) > before end, 'Wheel did not scroll both panes')
    assert(vim.api.nvim_get_current_win() == target, 'Hovered diff pane was not focused')
    assert(top(left) == top(right), 'Diff panes lost alignment')
    assert(top(sidebar) == 1, 'Sidebar scrolled with the diff')
    wheel(target, 'right')
    pause(20)
    assert(column(left) == 0 and column(right) == 0, 'Vertical-first gesture leaked horizontal scrolling')
    local down = top(left)
    wheel(target, 'up')
    wait(function() return top(left) < down and top(right) < down end, 'Upward wheel did not scroll both panes')
  end
  -- Rejected diagonal events still belong to the gesture, even after 150 ms total.
  pause(180)
  local before_mixed = top(left)
  wheel(right, 'down')
  wait(function() return top(left) > before_mixed end, 'Start continuous vertical gesture')
  local mixed_top = top(left)
  for _ = 1, 5 do
    wheel(right, 'right')
    pause(50)
    assert(column(left) == 0 and column(right) == 0, 'Continuous diagonal events reset the active axis')
    assert(top(left) == mixed_top and top(right) == mixed_top, 'Rejected events moved the diff')
  end
  wheel(right, 'up')
  wait(function() return top(left) < mixed_top and top(right) < mixed_top end, 'Vertical gesture lost its original axis')
  wheel(right, 'down')
  wait(function() return top(left) > before_mixed end, 'Position away from vertical boundary')

  pause(180)
  vim.api.nvim_set_current_win(sidebar)
  wheel(right, 'right')
  wait(function() return column(left) > 0 and column(right) > 0 end, 'Horizontal scrolling did not synchronize after quiet period')
  local horizontal_top, horizontal_column = top(left), column(left)
  for _, direction in ipairs({ 'down', 'up' }) do
    wheel(left, direction)
    pause(20)
    assert(top(left) == horizontal_top and top(right) == horizontal_top, 'Horizontal-first gesture leaked ' .. direction .. ' scrolling')
    assert(column(left) == horizontal_column and column(right) == horizontal_column, 'Rejected vertical event moved columns')
    assert(vim.api.nvim_get_current_win() == right, 'Rejected event changed focus')
  end
  wheel(left, 'left')
  wait(function() return column(left) == 0 and column(right) == 0 end, 'Horizontal return did not synchronize')
  for _, mode in ipairs({ 'i', 'v' }) do
    pause(180)
    vim.api.nvim_set_current_win(left)
    vim.api.nvim_input(mode)
    wait(function() return vim.api.nvim_get_mode().mode == mode end, 'Enter ' .. mode)
    local before = top(left)
    wheel(right, 'down')
    wait(function() return top(left) > before and top(right) > before end, mode .. ' scrolling did not synchronize')
    wheel(right, 'right')
    pause(20)
    assert(column(left) == 0 and column(right) == 0, mode .. ' gesture leaked horizontal scrolling')
    vim.api.nvim_input('<Esc>')
    wait(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Exit ' .. mode)
  end
  vim.api.nvim_set_current_win(left)
  vim.cmd('redraw')
  local before = top(left)
  wheel(sidebar, 'down')
  wait(function() return top(sidebar) > 1 end, 'Ordinary wheel scroll was swallowed')
  assert(vim.api.nvim_get_current_win() == left, 'Ordinary window stole focus')
  assert(top(left) == before, 'Scrolling sidebar moved the diff')
  pause(180)
  wheel(sidebar, 'right')
  wait(function() return column(sidebar) > 0 end, 'Ordinary horizontal wheel scroll was swallowed')
  assert(vim.api.nvim_get_current_win() == left, 'Ordinary horizontal scrolling stole focus')
  assert(column(left) == 0 and column(right) == 0, 'Scrolling sidebar horizontally moved the diff')
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('PASS mouse scrolling: gesture axis lock, mixed-event continuity, quiet reset, synchronized diff panes, native ordinary panes')
  vim.cmd('qa!')
end)
vim.schedule(resume)
