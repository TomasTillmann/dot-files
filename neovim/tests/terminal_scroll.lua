-- Run: nvim --headless '+luafile tests/terminal_scroll.lua'
-- Real keyboard input, shell process, and animated scrolling; temporary files only.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 10000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message .. ': ' .. vim.v.errmsg)
    vim.defer_fn(resume, 5)
    coroutine.yield()
  end
end
runner = coroutine.create(function()
  vim.o.columns, vim.o.lines = 160, 50
  vim.cmd('enew')
  local editor = vim.api.nvim_get_current_win()
  local root = vim.fn.tempname() .. '-terminal'
  vim.fn.mkdir(root, 'p')
  root = assert(vim.uv.fs_realpath(root))
  vim.cmd.cd(vim.fn.fnameescape(root))
  vim.api.nvim_input('<Esc>')
  wait(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Normal mode')
  vim.api.nvim_input(' t')
  wait(function() return vim.bo.filetype == 'toggleterm' and vim.api.nvim_get_mode().mode == 't' end, 'Terminal shortcut')
  local term = require('toggleterm.terminal').get(1)
  local buf, job = term.bufnr, term.job_id
  local config = vim.api.nvim_win_get_config(term.window)
  assert(config.relative == 'editor' and config.width == 144 and config.height == 45, 'Expected 90% floating terminal')
  local function output(expected)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if vim.trim(line) == expected then return true end
    end
    return false
  end
  vim.api.nvim_input("NVIM_TERMINAL_PROBE=kept; printf 'READY:%s\\n' \"$NVIM_TERMINAL_PROBE\"<CR>")
  wait(function() return output('READY:kept') end, 'Shell command output')

  -- Click a Git-style MR URL without opening a real browser during the test.
  local url = 'https://example.com/team/project/-/merge_requests/196'
  local open, opened = vim.ui.open, {}
  vim.ui.open = function(target) opened[#opened + 1] = target end
  vim.api.nvim_chan_send(job, "printf '\\nremote:  " .. url .. "\\n'\n")
  wait(function() return output('remote:  ' .. url) end, 'MR link output')
  local function click_url(offset)
    vim.cmd('redraw')
    for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if vim.trim(line) == 'remote:  ' .. url then
        local column = assert(line:find(url, 1, true)) + offset
        local pos = vim.fn.screenpos(term.window, row, column)
        assert(pos.row > 0 and pos.col > 0, 'MR link is not visible')
        vim.api.nvim_input_mouse('left', 'press', '', 0, pos.row - 1, pos.col - 1)
        vim.api.nvim_input_mouse('left', 'release', '', 0, pos.row - 1, pos.col - 1)
        return
      end
    end
    error('MR link disappeared')
  end
  click_url(20)
  wait(function() return #opened == 1 end, 'Click did not open MR link')
  assert(opened[1] == url, 'Click opened an incomplete/wrong URL')
  assert(vim.api.nvim_get_mode().mode == 't', 'Opening a link stopped terminal input')
  click_url(-5) -- Ordinary terminal output retains native mouse behavior.
  local clicked = vim.uv.hrtime() + 100000000
  wait(function() return vim.uv.hrtime() >= clicked end, 'Process ordinary mouse click')
  assert(vim.api.nvim_get_mode().mode == 't', 'Ordinary click stopped terminal input')
  assert(#opened == 1, 'Non-link text opened in the browser')
  vim.ui.open = open
  vim.api.nvim_input('<Esc><Esc>')
  wait(function() return not term:is_open() and vim.api.nvim_get_current_win() == editor end, 'Hide from shell')
  assert(vim.fn.jobwait({ job }, 0)[1] == -1, 'Hiding killed the shell')
  vim.api.nvim_input(' t')
  wait(function() return term:is_open() and vim.api.nvim_get_mode().mode == 't' end, 'Reopen shell')
  assert(term.bufnr == buf and term.job_id == job and output('READY:kept'), 'Shell/output were replaced')
  vim.api.nvim_input("printf 'PERSIST:%s\\n' \"$NVIM_TERMINAL_PROBE\"; pwd<CR>")
  wait(function() return output('PERSIST:kept') and output(root) end, 'Shell variable and cwd persistence')
  vim.api.nvim_input([[<C-\><C-n>]])
  wait(function() return not term:is_open() and vim.api.nvim_get_current_win() == editor end, 'Native terminal escape hides popup')
  vim.api.nvim_input(' t')
  wait(function() return term:is_open() and vim.api.nvim_get_mode().mode == 't' end, 'Reopen ready to type')
  vim.api.nvim_input('exit<CR>')
  wait(function() return not term:is_open() and vim.api.nvim_get_current_win() == editor end, 'Exit shell')
  print('PASS ToggleTerm: popup size, shortcuts, URL clicks, terminal input after clicks, ordinary clicks, shell persistence, exit')

  vim.api.nvim_input('<Esc>')
  wait(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Return to Normal mode')
  local lines = {}
  for i = 1, 300 do lines[i] = 'line ' .. i end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 100, 0 })
  vim.cmd('normal! zz')
  vim.cmd('redraw')
  local function check_scroll(key, delta, other)
    local top, row = vim.fn.line('w0'), vim.fn.line('.')
    local intermediate = false
    vim.api.nvim_input(key)
    wait(function()
      local distance = vim.fn.line('w0') - top
      if distance ~= 0 and distance ~= delta then intermediate = true end
      return distance == delta and vim.fn.line('.') == row + delta
    end, 'Scroll distance for ' .. key)
    assert(intermediate, 'Scroll was not animated')
    if other then assert(vim.fn.line('w0', other) == vim.fn.line('w0'), 'Diff panes lost synchronization: ' .. vim.fn.line('w0', other) .. '/' .. vim.fn.line('w0')) end
  end
  check_scroll('<C-d>', 10)
  check_scroll('<C-u>', -10)
  vim.cmd('diffthis')
  local left = vim.api.nvim_get_current_win()
  vim.wo.foldenable = false
  vim.cmd('vnew')
  lines[150] = 'changed line'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.cmd('diffthis')
  vim.wo.foldenable = false
  vim.api.nvim_win_set_cursor(0, { 100, 0 })
  vim.cmd('normal! zz')
  vim.cmd('redraw')
  vim.cmd('syncbind')
  vim.cmd('redraw')
  check_scroll('<C-d>', 10, left)
  check_scroll('<C-u>', -10, left)
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('PASS Neoscroll: animated 10-line up/down movement, matching cursor distance, synchronized diff panes')
  vim.cmd('qa!')
end)
vim.schedule(resume)
