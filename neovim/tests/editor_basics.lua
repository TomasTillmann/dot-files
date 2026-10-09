-- Run: env -u VIRTUAL_ENV nvim --headless '+luafile tests/editor_basics.lua'
-- Real keys through the active config; files live in Neovim's temporary directory.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function pause(ms) vim.defer_fn(resume, ms); coroutine.yield() end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 10e9
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message)
    pause(20)
  end
end
local function keys(text, message)
  vim.api.nvim_input(text)
  wait(function() return vim.api.nvim_get_mode().blocking == false and vim.fn.getchar(1) == 0 end, 'Keys were not processed: ' .. (message or text))
  pause(30)
end
local function line(n) return vim.api.nvim_buf_get_lines(0, n - 1, n, false)[1] end

runner = coroutine.create(function()
  pause(200)

  -- Start screen, theme and status line.
  assert(vim.bo.filetype == 'ministarter', 'Start screen did not open: ' .. vim.bo.filetype)
  local screen = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  for _, item in ipairs({ 'Find file', 'Find type', 'File tree', 'Grep search', 'Keymaps' }) do
    assert(screen:find(item, 1, true), 'Start screen is missing ' .. item)
  end
  assert(vim.g.colors_name and vim.g.colors_name:find('^catppuccin'), 'Catppuccin is not the active theme')
  assert(vim.o.statusline:find('MiniStatusline', 1, true), 'mini.statusline is not active')
  local starter_buf = vim.api.nvim_get_current_buf()
  for _, shortcut in ipairs({ { 'f', 'Files' }, { 'g', 'Live Grep' }, { 'k', 'Key Maps' }, { '<CR>', 'Files' } }) do
    keys(shortcut[1], 'start screen ' .. shortcut[1])
    wait(function() return vim.bo.filetype == 'TelescopePrompt' end, 'Start-screen key ' .. shortcut[1] .. ' did not open a picker')
    local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
    assert(picker.prompt_title:find(shortcut[2], 1, true), shortcut[1] .. ' opened the wrong picker: ' .. picker.prompt_title)
    require('telescope.actions').close(vim.api.nvim_get_current_buf())
    wait(function() return vim.api.nvim_get_current_buf() == starter_buf end, 'Picker did not return to the start screen')
  end
  assert(vim.fn.maparg('t', 'n', false, true).desc == 'Find type', 'Start-screen t is not the type-search shortcut')
  print('PASS start screen: items, f/g/k/Enter shortcuts, t mapped, Catppuccin, statusline')

  local base = vim.fn.tempname() .. '-nvim-basics'
  vim.fn.mkdir(base, 'p')
  base = assert(vim.uv.fs_realpath(base))
  vim.o.undodir = base .. '/undo' -- Keep test undo files out of the real state directory.
  vim.fn.mkdir(vim.o.undodir, 'p')

  -- Search: ? searches backwards, Escape clears highlights, smart case.
  local file = base .. '/notes.txt'
  vim.fn.writefile({ 'alpha', 'Beta', 'alpha', 'beta' }, file)
  vim.cmd.edit(vim.fn.fnameescape(file))
  -- Core options, checked in an ordinary file window.
  local expected = {
    number = true, wrap = false, undofile = true, ignorecase = true, smartcase = true, signcolumn = 'yes', scrolloff = 10,
    splitright = true, splitbelow = true, confirm = true, inccommand = 'split', foldenable = false, clipboard = 'unnamedplus',
  }
  for name, value in pairs(expected) do
    assert(vim.o[name] == value, ('Option %s is %s, expected %s'):format(name, vim.inspect(vim.o[name]), vim.inspect(value)))
  end
  assert(vim.g.mapleader == ' ', 'Space is not the leader')
  print('PASS options: numbers, no wrap, persistent undo, smart case, sign column, splits, clipboard')

  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  keys('?alpha<CR>')
  assert(vim.fn.line('.') == 3, '? did not search backwards')
  assert(vim.v.hlsearch == 1, 'Search highlighting is off')
  keys('<Esc>')
  assert(vim.v.hlsearch == 0, 'Escape did not clear search highlighting')
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  keys('/Beta<CR>')
  assert(vim.fn.line('.') == 2, 'Smart-case search matched the wrong case')
  keys('<Esc>')
  print('PASS search: ? backwards, Escape clears highlights, smart case')

  -- Yank highlight and persistent undo across reopening a file.
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  keys('yy')
  local yank = vim.api.nvim_get_namespaces()['nvim.hlyank']
  assert(yank and #vim.api.nvim_buf_get_extmarks(0, yank, 0, -1, {}) > 0, 'Yanked text was not highlighted')
  keys('ccchanged<Esc>')
  vim.cmd.write()
  vim.cmd('bwipeout')
  vim.cmd.edit(vim.fn.fnameescape(file))
  assert(line(1) == 'changed', 'Edit was not saved')
  keys('u')
  assert(line(1) == 'alpha', 'Undo history did not survive reopening the file')
  vim.cmd('silent write')
  print('PASS editing: yank highlight, persistent undo')

  -- Clipboard: yanks reach macOS and copied text pastes; the user's clipboard is restored afterwards.
  local saved = vim.system({ 'pbpaste' }, { text = true }):wait().stdout
  local ok, clipboard_err = pcall(function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    keys('yy')
    assert(vim.system({ 'pbpaste' }, { text = true }):wait().stdout == 'Beta\n', 'Yank did not reach the macOS clipboard')
    vim.system({ 'pbcopy' }, { stdin = 'from macOS\n' }):wait()
    keys('Gp')
    assert(line(5) == 'from macOS', 'p did not paste the macOS clipboard: ' .. tostring(line(5)))
    keys('u')
  end)
  vim.system({ 'pbcopy' }, { stdin = saved }):wait()
  assert(ok, clipboard_err)
  print('PASS clipboard: yank to and paste from the macOS clipboard')

  -- Text objects and surround (mini.ai / mini.surround).
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'call(first, second)', 'word' })
  vim.api.nvim_win_set_cursor(0, { 1, 12 })
  keys('cianew<Esc>')
  assert(line(1) == 'call(first, new)', 'Argument text object failed: ' .. line(1))
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  keys('saiw"')
  assert(line(2) == '"word"', 'Add-surrounding failed: ' .. line(2))
  keys('sd"')
  assert(line(2) == 'word', 'Delete-surrounding failed: ' .. line(2))
  vim.cmd('silent write')
  print('PASS text objects: argument change, add/delete surrounding')

  -- Indentation is detected from file contents.
  local tabs, twos = base .. '/tabs.py', base .. '/twos.lua'
  vim.fn.writefile({ 'def f():', '\treturn 1', '', 'def g():', '\treturn 2' }, tabs)
  vim.fn.writefile({ 'if x then', '  y()', '  if z then', '    w()', '  end', 'end' }, twos)
  vim.cmd.edit(tabs)
  wait(function() return not vim.bo.expandtab end, 'Tab indentation was not detected')
  vim.cmd.edit(twos)
  wait(function() return vim.bo.shiftwidth == 2 and vim.bo.expandtab end, 'Two-space indentation was not detected')
  print('PASS indentation: tabs and two-space files detected')

  -- Ctrl h/j/k/l move between splits.
  vim.cmd.only()
  local main = vim.api.nvim_get_current_win()
  vim.cmd.vsplit()
  local right = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_get_position(right)[2] > vim.api.nvim_win_get_position(main)[2], 'Vertical split did not open on the right')
  vim.cmd.split()
  local below = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_get_position(below)[1] > vim.api.nvim_win_get_position(right)[1], 'Horizontal split did not open below')
  keys('<C-k>'); assert(vim.api.nvim_get_current_win() == right, 'Ctrl-k did not move up')
  keys('<C-j>'); assert(vim.api.nvim_get_current_win() == below, 'Ctrl-j did not move down')
  keys('<C-h>'); assert(vim.api.nvim_get_current_win() == main, 'Ctrl-h did not move left')
  keys('<C-l>'); assert(vim.api.nvim_get_current_win() ~= main, 'Ctrl-l did not move right')
  vim.cmd.only()
  print('PASS windows: splits open right/below, Ctrl-h/j/k/l move focus')

  -- - reveals the current file in the tree.
  vim.cmd.cd(vim.fn.fnameescape(base))
  vim.cmd.edit(vim.fn.fnameescape(file))
  keys('-')
  wait(function() return vim.bo.filetype == 'neo-tree' end, '- did not open the file tree')
  wait(function()
    local node = require('neo-tree.sources.manager').get_state('filesystem').tree:get_node()
    return node and node.path == file
  end, '- did not select the current file in the tree')
  print('PASS file tree: - reveals the current file')

  vim.cmd('qa!')
end)
vim.schedule(resume)
