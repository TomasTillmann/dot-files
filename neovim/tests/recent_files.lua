-- Run: nvim --headless '+luafile tests/recent_files.lua'
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function wait(predicate)
  local deadline = vim.uv.hrtime() + 5000000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, 'Recent files picker timed out: ' .. vim.v.errmsg)
    vim.defer_fn(resume, 10); coroutine.yield()
  end
end
runner = coroutine.create(function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  for _, name in ipairs({ 'first.txt', 'second.txt' }) do vim.fn.writefile({ name }, root .. '/' .. name) end
  vim.cmd.edit(root .. '/first.txt')
  local editor = vim.api.nvim_get_current_win()
  local function pick(expected)
    vim.api.nvim_input('<Esc>')
    wait(function() return vim.api.nvim_get_mode().mode == 'n' end)
    vim.api.nvim_input('  ')
    wait(function() return vim.bo.filetype == 'TelescopePrompt' end)
    local state = require('telescope.actions.state')
    wait(function() return state.get_selected_entry() ~= nil end)
    assert(state.get_selected_entry().filename:match(expected .. '$'))
    vim.api.nvim_input('<CR>')
    wait(function() return vim.bo.filetype ~= 'TelescopePrompt' end)
    assert(vim.api.nvim_get_current_win() == editor)
    assert(vim.api.nvim_buf_get_name(0):match(expected .. '$'))
  end
  pick('first.txt') -- Single-file editor must still open the picker.
  vim.cmd.edit(root .. '/second.txt')
  pick('first.txt')
  pick('second.txt')
  vim.cmd('Neotree filesystem left')
  wait(function() return vim.bo.filetype == 'neo-tree' end)
  local ready = vim.uv.hrtime() + 300000000
  wait(function() return vim.uv.hrtime() > ready end)
  pick('second.txt')
  print('PASS recent files: sole file, MRU switching, tree launch, original editor preserved')
  vim.cmd('qa!')
end)
vim.schedule(resume)
