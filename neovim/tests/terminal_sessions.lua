-- Run: nvim --headless '+luafile tests/terminal_sessions.lua'
-- Real keyboard input and isolated shell processes; no user shell history.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 10000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message .. ': ' .. vim.v.errmsg)
    vim.defer_fn(resume, 5); coroutine.yield()
  end
end
runner = coroutine.create(function()
  vim.o.columns, vim.o.lines, vim.o.shell = 160, 50, '/bin/zsh'
  local root = vim.fn.tempname() .. '-terminal-sessions'
  vim.fn.mkdir(root .. '/nested', 'p')
  root = assert(vim.uv.fs_realpath(root))
  vim.env.ZDOTDIR = root .. '/zsh'
  vim.fn.mkdir(vim.env.ZDOTDIR, 'p')
  vim.fn.writefile({
    'unset HISTFILE',
    "PROMPT='POPUP> '; RPROMPT=''",
    'bindkey -v', -- Prove the popup hook overrides inherited Vi editing.

    'source ' .. vim.fn.shellescape(vim.fn.stdpath('config') .. '/shell/popup.zsh'),
  }, vim.env.ZDOTDIR .. '/.zshrc')
  vim.cmd.cd(root)
  vim.cmd('tabnew')
  local editor, tab = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_tabpage()
  local tabs = vim.api.nvim_list_tabpages()
  assert(vim.fn.maparg(' t', 'n') ~= '', 'Space+t terminal shortcut missing')
  for _, mode in ipairs({ 'n', 'i', 't' }) do
    assert(vim.fn.maparg('<C-§>', mode) == '', 'Old Ctrl+§ shortcut remains')
  end
  for _, mode in ipairs({ 'n', 'i', 't' }) do
    assert(vim.fn.maparg([[<C-\>]], mode) == '', 'Old Ctrl+backslash terminal shortcut remains in ' .. mode)
  end
  vim.api.nvim_input(' t')
  wait(function() return vim.bo.filetype == 'toggleterm' and vim.api.nvim_get_mode().mode == 't' end, 'Open popup')
  local terms = require('toggleterm.terminal')
  local first = assert(terms.get(1))
  assert(vim.fn.maparg('<C-q>', 't') == '', 'Popup must not require or intercept Ctrl+q')
  assert(vim.fn.maparg('t', 'n') == '', 'Bare t must retain native Normal-mode behavior')
  assert(vim.fn.maparg('<Esc>', 't') == '', 'Single Escape must reach the terminal program')
  local escape = vim.fn.maparg('<Esc><Esc>', 't', false, true)
  assert(escape.buffer == 1, 'Double Escape must hide this popup')
  for _, maps in ipairs({ vim.api.nvim_get_keymap('t'), vim.api.nvim_buf_get_keymap(first.bufnr, 't') }) do
    for _, map in ipairs(maps) do
      local lhs = vim.api.nvim_replace_termcodes(map.lhs, true, false, true)
      assert(lhs:sub(1, 1) ~= ' ', 'Terminal input must not delay or consume Space: ' .. map.lhs)
    end
  end
  local function output(term, expected)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false)) do
      if vim.trim(line) == expected then return true end
    end
    return false
  end
  local function selected(index)
    local term = terms.get(index)
    return term and term:is_focused() and vim.api.nvim_get_mode().mode == 't'
  end
  local function title(term)
    local parts = {}
    for _, part in ipairs(vim.api.nvim_win_get_config(term.window).title) do parts[#parts + 1] = part[1] end
    return table.concat(parts)
  end
  local function click_slot(index)
    local term = terms.get(require('toggleterm.terminal').get_focused_id())
    local text = title(term)
    local position = vim.api.nvim_win_get_position(term.window)
    local offset = assert(text:find(tostring(index), 1, true)) - 1
    local column = position[2] + 1 + math.floor((vim.api.nvim_win_get_width(term.window) - #text) / 2) + offset
    vim.cmd('redraw')
    vim.api.nvim_input_mouse('left', 'press', '', 0, position[1], column)
    vim.api.nvim_input_mouse('left', 'release', '', 0, position[1], column)
    local settle = vim.uv.hrtime() + 100000000
    wait(function() return vim.uv.hrtime() >= settle end, 'Process slot mouse release')
  end
  assert(title(first) == ' [1]  2  3  4  5  6  7  8  9 ', 'Nine slots are not visible')
  assert(#terms.get_all() == 1, 'Unused slots should not spawn idle shells')
  vim.api.nvim_input("NVIM_POPUP_TEST=123456789; cd nested; printf '\\nFIRST:%s\\n' \"$NVIM_POPUP_TEST\"<CR>")
  wait(function() return output(first, 'FIRST:123456789') end, 'Literal number input')
  vim.api.nvim_input("printf '\\nLITERAL:%s\\n' 123456789<CR>")
  wait(function() return output(first, 'LITERAL:123456789') end, 'Space followed immediately by digits must reach the shell')
  vim.api.nvim_input("test -n \"$NVIM_POPUP_TEST\" && printf '\\nT_INPUT:ok\\n'<CR>")
  wait(function() return output(first, 'T_INPUT:ok') end, 'Literal t must reach the shell while typing')
  assert(first:is_open() and vim.api.nvim_get_mode().mode == 't', 'Typing t closed the popup')
  local first_buf, first_job = first.bufnr, first.job_id
  vim.api.nvim_input("sleep 30 & BG_PID=$!; printf '\\nBACKGROUND_READY\\n'<CR>")
  wait(function() return output(first, 'BACKGROUND_READY') end, 'Prompt available with background job running')
  vim.api.nvim_input('<Esc>')
  local settle = vim.uv.hrtime() + 500000000
  wait(function() return vim.uv.hrtime() >= settle end, 'Single Escape timeout')
  assert(selected(1), 'Single Escape entered Normal mode or hid the popup')
  vim.api.nvim_input('<C-g>') -- Cancel zsh's Escape/Meta prefix before the next command.
  vim.api.nvim_input([[kill "$BG_PID"; wait "$BG_PID" 2>/dev/null; unset BG_PID; printf '\nBACKGROUND_DONE\n'<CR>]])
  wait(function() return output(first, 'BACKGROUND_DONE') end, 'Background job cleanup')
  vim.api.nvim_input('<Esc><Esc>')
  wait(function() return not first:is_open() and vim.api.nvim_get_current_win() == editor end, 'Double Escape hides popup')
  assert(vim.fn.jobwait({ first_job }, 0)[1] == -1, 'Hiding killed the shell')
  vim.api.nvim_input(' t')
  wait(function() return selected(1) end, 'Reopen first session before clicking slots')
  for index = 2, 9 do
    local previous = terms.get(index - 1)
    click_slot(index)
    wait(function() return selected(index) end, 'Click terminal slot ' .. index)
    assert(not previous:is_open() and vim.fn.jobwait({ previous.job_id }, 0)[1] == -1, 'Click must hide and preserve the previous shell')
    assert(title(terms.get(index)):find('[' .. index .. ']', 1, true), 'Active slot is not marked')
    assert(#vim.api.nvim_list_tabpages() == #tabs and vim.api.nvim_get_current_tabpage() == tab, 'Popup changed editor tabs')
  end
  click_slot(9)
  assert(selected(9), 'Clicking the active slot hid the popup')
  local position = vim.api.nvim_win_get_position(terms.get(9).window)
  local left = position[2] + 1 + math.floor((vim.api.nvim_win_get_width(terms.get(9).window) - #title(terms.get(9))) / 2)
  -- A negative Lua string index must not mistake blank border for a slot number.
  assert(not require('popup_terminal').click_title(terms.get(9), { screenrow = position[1] + 1, screencol = left - 1 }), 'Blank border switched slots')
  assert(#terms.get_all() == 9, 'Not all nine sessions are available')
  local ninth = terms.get(9)
  vim.api.nvim_input("printf '\\nNINTH:%s\\n' \"${NVIM_POPUP_TEST-unset}\"<CR>")
  wait(function() return output(ninth, 'NINTH:unset') end, 'Sessions do not have independent shell state')
  vim.api.nvim_input('<Esc><Esc>')
  wait(function() return not ninth:is_open() and vim.api.nvim_get_current_win() == editor end, 'Double Escape hides another session')
  vim.api.nvim_input(' t')
  wait(function() return selected(9) end, 'Space+t reopens last session ready to type')
  assert(output(ninth, 'NINTH:unset'), 'Reopening lost terminal output')
  click_slot(1)
  wait(function() return selected(1) end, 'Click back to first session')
  assert(first.bufnr == first_buf and first.job_id == first_job and output(first, 'FIRST:123456789'), 'Switching replaced the shell')
  vim.api.nvim_input("printf '\\nPERSIST:%s\\n' \"$NVIM_POPUP_TEST\"; pwd<CR>")
  wait(function() return output(first, 'PERSIST:123456789') and output(first, root .. '/nested') end, 'Shell variable and working directory persistence')
  -- Single Escape reaches the child editor; double Escape hides it intact.
  local message = root .. '/nested/COMMIT_EDITMSG'
  vim.fn.writefile({ 'COMMIT_PROBE', '# disposable commit message' }, message)
  vim.api.nvim_input(vim.fn.shellescape(vim.v.progpath) .. ' -u NONE -i NONE -n COMMIT_EDITMSG; printf "\\nNESTED_EXITED:%s\\n" "$?"<CR>')
  wait(function() return output(first, 'COMMIT_PROBE') end, 'Nested commit editor ready')
  vim.api.nvim_input('iFIRST_<Esc>A_SECOND')
  wait(function() return output(first, 'FIRST_COMMIT_PROBE_SECOND') end, 'Escape reaches the child editor before append')
  assert(vim.api.nvim_get_mode().mode == 't', 'Escape left outer terminal input')
  vim.api.nvim_input('<Esc><Esc>')
  wait(function() return not first:is_open() and vim.api.nvim_get_current_win() == editor end, 'Double Escape hides a running child editor')
  assert(vim.fn.jobwait({ first_job }, 0)[1] == -1, 'Hiding killed the child editor')
  vim.api.nvim_input(' t')
  wait(function() return selected(1) end, 'Reopen child editor ready for input')
  vim.api.nvim_input('<Esc>:wq<CR>')
  wait(function() return output(first, 'NESTED_EXITED:0') end, 'Nested commit editor returned to shell')
  assert(vim.fn.readfile(message)[1] == 'FIRST_COMMIT_PROBE_SECOND', 'Single Escape and :wq did not save the child editor')
  vim.api.nvim_input('<Esc><Esc>')
  wait(function() return not first:is_open() end, 'Hide first session')
  vim.cmd('9ToggleTerm')
  wait(function() return selected(9) end, 'Return to ninth session')
  vim.o.columns = 150
  vim.api.nvim_exec_autocmds('VimResized', {})
  assert(title(ninth):find('[9]', 1, true) and vim.api.nvim_win_get_config(ninth.window).title_pos == 'center', 'Resize lost active title')
  click_slot(1)
  wait(function() return selected(1) end, 'Click first slot after resize')
  click_slot(9)
  wait(function() return selected(9) end, 'Click ninth slot after resize')
  local old_job = ninth.job_id
  vim.api.nvim_input('exit<CR>')
  wait(function() return not ninth:is_open() and terms.get(9) == nil end, 'Exit removes only that shell')
  vim.api.nvim_input(' t')
  wait(function() return selected(9) end, 'Recreate exited last-used slot')
  assert(terms.get(9).job_id ~= old_job and vim.fn.jobwait({ first_job }, 0)[1] == -1, 'Exit killed another session or did not recreate its job')
  vim.api.nvim_input('<Esc><Esc>')
  wait(function() return not terms.get(9):is_open() and vim.api.nvim_get_current_win() == editor end, 'Double Escape returns to editor')
  assert(vim.api.nvim_get_mode().mode == 'n', 'Closing popup left editor in Insert mode')
  assert(vim.fn.maparg('<Esc>', 't') == '', 'Popup Escape mapping leaked into the editor')
  assert(vim.fn.maparg('1', 'n', false, true).buffer == 0, 'Popup session mapping leaked into the editor')
  vim.api.nvim_input('1')
  wait(function() return vim.api.nvim_get_current_tabpage() == tabs[1] end, 'Editor number mapping preserved')
  for _, term in ipairs(terms.get_all()) do term:shutdown() end
  vim.fn.delete(root, 'rf')
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('PASS popup sessions: nine clickable slots, active-slot click, resized title clicks, single Escape reaches nested editor, double Escape hides running editor, Space+t opens, literal input, shell state, last session, resize, exit/recreation, editor keys')
  vim.cmd('qa!')
end)
vim.schedule(resume)
