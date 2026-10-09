-- Run: env -u VIRTUAL_ENV nvim --headless '+luafile tests/restart.lua'
-- Real :restart: a Neovim with a terminal UI (in a pseudo-terminal) in a disposable Git repository,
-- driven over its socket. Verifies the workspace and open files come back without errors.
local runner, child, channel
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then
    vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err)))
    if child then vim.fn.jobstop(child) end
    vim.cmd('cquit 1')
  end
end
local function pause(ms) vim.defer_fn(resume, ms); coroutine.yield() end
local function wait(predicate, message)
  local deadline = vim.uv.hrtime() + 30e9
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message)
    pause(100)
  end
end

runner = coroutine.create(function()
  local repo = vim.fn.tempname() .. '-restart'
  vim.fn.mkdir(repo, 'p')
  repo = assert(vim.uv.fs_realpath(repo))
  local function git(...) assert(vim.system({ 'git', '-C', repo, ... }):wait().code == 0, 'git ' .. table.concat({ ... }, ' ')) end
  git('init', '-q', '-b', 'main')
  git('config', 'user.email', 'test@example.invalid')
  git('config', 'user.name', 'Test')
  vim.fn.writefile({ 'one' }, repo .. '/a.txt')
  git('add', 'a.txt')
  git('commit', '-q', '-m', 'init')
  vim.fn.writefile({ 'one', 'two' }, repo .. '/a.txt')

  local socket = vim.fn.tempname() .. '.s' -- Short: macOS limits socket paths to ~104 bytes.
  child = vim.fn.jobstart({ 'nvim', '--listen', socket }, {
    pty = true, width = 160, height = 45, cwd = repo, env = { TERM = 'xterm-256color', VIRTUAL_ENV = '' },
  })
  assert(child > 0, 'Could not start Neovim in a pseudo-terminal')
  -- Only one-way messages to the child: a Neovim stuck at an error prompt must fail the test, not hang it.
  local report = vim.fn.tempname() .. '-state.json'
  local probe = [[
    local tabs = {}
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      local filetypes, files = {}, {}
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local buf = vim.api.nvim_win_get_buf(win)
        filetypes[vim.bo[buf].filetype] = true
        files[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')] = true
      end
      tabs[#tabs + 1] = { title = vim.t[tab].workspace_title or vim.t[tab].diffview_title, filetypes = filetypes, files = files }
    end
    local placeholders = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if (name:find('neo%-tree') and vim.bo[buf].filetype ~= 'neo-tree') or (name:find('^diffview://null') and vim.bo[buf].buflisted) then
        placeholders = placeholders + 1
      end
    end
    local state = { reason = vim.v.startreason, errmsg = vim.v.errmsg, blocking = vim.api.nvim_get_mode().blocking, tabs = tabs, placeholders = placeholders }
    vim.fn.writefile({ vim.json.encode(state) }, ...)
  ]]
  local function connect()
    local ok, id = pcall(vim.fn.sockconnect, 'pipe', socket, { rpc = true })
    if ok and id > 0 then channel = id; return true end
    return false
  end
  local function state()
    vim.fn.delete(report)
    if not pcall(vim.rpcnotify, channel, 'nvim_exec_lua', probe, { report }) then return nil end
    local deadline = vim.uv.hrtime() + 3e9
    while not vim.uv.fs_stat(report) do
      if vim.uv.hrtime() > deadline then return nil end
      pause(50)
    end
    pause(50)
    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(report), '\n'))
    return ok and decoded or nil
  end
  local function check(expected_reason)
    local s = assert(state(), 'Neovim stopped responding (blocked at an error prompt?)')
    assert(s.reason == expected_reason, 'Unexpected start reason: ' .. s.reason)
    assert(s.errmsg == '' and not s.blocking, 'Startup error: ' .. s.errmsg)
    assert(#s.tabs == 3, 'Expected Panel and two Git tabs, got ' .. vim.inspect(s.tabs))
    local panel, changes = s.tabs[1], s.tabs[2]
    assert(panel.title == 'Panel' and panel.filetypes['neo-tree'] and panel.files['a.txt'], 'Panel lacks the tree or the open file: ' .. vim.inspect(panel))
    assert(changes.title == 'Current Changes' and changes.filetypes['DiffviewFiles'], 'Current Changes tab missing: ' .. vim.inspect(changes))
    assert(s.tabs[3].title == 'Changes against main', 'Branch comparison tab missing: ' .. vim.inspect(s.tabs[3]))
    assert(s.placeholders == 0, 'Session placeholder buffers were left behind')
  end

  wait(function()
    local s = connect() and state()
    return s and #s.tabs == 3
  end, 'Neovim with a terminal UI did not open its workspace tabs')
  vim.rpcnotify(channel, 'nvim_input', '<C-w>l:edit a.txt<CR>')
  wait(function()
    local s = state()
    return s and s.tabs[1].files['a.txt']
  end, 'Could not open a.txt')
  check('normal')
  -- Load the Current Changes diff first: then that Git tab also shows the real a.txt, which must not survive as a stray tab.
  vim.rpcnotify(channel, 'nvim_input', '2')
  wait(function()
    local s = state()
    return s and s.tabs[2].files['a.txt']
  end, 'Current Changes did not show the a.txt diff')
  vim.rpcnotify(channel, 'nvim_input', '1')
  pause(300)

  vim.rpcnotify(channel, 'nvim_input', ':restart<CR>')
  pause(1000)
  local last
  local restored = pcall(wait, function()
    last = connect() and state() or last
    return last and last.reason == 'restart' and #last.tabs == 3 and last.tabs[1].files['a.txt'] and last.tabs[2].filetypes['DiffviewFiles']
  end, 'timeout')
  assert(restored, 'Workspace was not restored after :restart; last answer: ' .. vim.inspect(last))
  check('restart')
  print('PASS :restart: no session errors, Panel/tree/open file restored, Git tabs rebuilt, no placeholder buffers')

  pcall(vim.rpcnotify, channel, 'nvim_command', 'qa!')
  pause(500)
  vim.fn.jobstop(child)
  vim.cmd('qa!')
end)
vim.schedule(resume)
