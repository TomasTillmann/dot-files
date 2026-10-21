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
  assert(vim.g.colors_name and vim.g.colors_name:find('^rose%-pine'), 'Rose Pine is not the active theme')
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
  print('PASS start screen: items, f/g/k/Enter shortcuts, t mapped, Rose Pine, statusline')

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

  vim.cmd.cd(vim.fn.fnameescape(base))
  vim.o.columns = 160
  local function preview_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.b[vim.api.nvim_win_get_buf(win)].preview_pane then return win end
    end
  end
  local function previewed() local win = preview_win(); return win and vim.b[vim.api.nvim_win_get_buf(win)].preview_pane end
  -- Space e shows the folder tree in the same window, on the current file; Space e again returns to the file.
  vim.cmd.edit(vim.fn.fnameescape(file))
  local file_win, file_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  keys(' e')
  wait(function() return vim.bo.filetype == 'neo-tree' end, 'Space e did not open the folder tree')
  assert(vim.api.nvim_get_current_win() == file_win, 'Space e opened the tree in another window')
  wait(function()
    local node = require('neo-tree.sources.manager').get_state('filesystem', nil, file_win).tree:get_node()
    return node and node.path == file
  end, 'Space e did not select the current file in the tree')
  wait(function() return previewed() == file end, 'The first Space e did not preview the current file')
  assert(vim.api.nvim_get_current_win() == file_win, 'The preview took focus from the tree')
  keys(' e')
  wait(function() return vim.api.nvim_get_current_buf() == file_buf end, 'Space e in the tree did not return to the file')
  print('PASS folder tree: Space e toggles a full-window tree on the current file')

  -- The tree previews the file under the cursor on the right while focus stays in the tree.
  local long = base .. '/long.py'
  local long_lines = {}
  for i = 1, 300 do long_lines[i] = 'value_' .. i .. ' = ' .. i end
  vim.fn.writefile(long_lines, long)
  keys(' e')
  wait(function() return previewed() == file end, 'The tree did not preview the current file')
  assert(vim.bo.filetype == 'neo-tree', 'Opening the preview moved focus out of the tree')
  assert(vim.api.nvim_win_get_position(preview_win())[2] > 0, 'The preview did not open on the right')
  local tree_state = require('neo-tree.sources.manager').get_state('filesystem', nil, file_win)
  local function cursor_path() return tree_state.tree:get_node().path end
  local moved = false
  for _ = 1, 5 do
    keys('k')
    if cursor_path() == long then moved = true; break end
  end
  assert(moved, 'Could not move the tree cursor onto long.py')
  wait(function() return previewed() == long end, 'The preview did not follow the tree cursor')
  assert(vim.api.nvim_get_current_win() == file_win, 'Moving in the tree moved focus out of it')
  assert(not vim.bo[vim.api.nvim_win_get_buf(preview_win())].modifiable, 'The preview is editable')
  keys('<C-d>')
  assert(vim.fn.line('w0', preview_win()) > 1, 'Ctrl-d in the tree did not scroll the preview')
  assert(vim.api.nvim_get_current_win() == file_win, 'Ctrl-d moved focus out of the tree')
  keys('P'); wait(function() return preview_win() == nil end, 'P did not hide the preview')
  keys('P'); wait(function() return previewed() == long end, 'P did not bring the preview back')
  keys('l'); assert(vim.api.nvim_get_current_win() == preview_win(), 'l did not move into the preview')
  keys('q'); assert(vim.api.nvim_get_current_win() == file_win, 'q in the preview did not return to the tree')
  keys(' e')
  wait(function() return preview_win() == nil and vim.bo.filetype ~= 'neo-tree' end, 'Closing the tree left the preview open')
  print('PASS folder tree preview: follows the cursor on the right, focus stays in the tree, Ctrl-d scrolls, P/l/q work, closes with the tree')

  vim.cmd('qa!')
end)
vim.schedule(resume)
