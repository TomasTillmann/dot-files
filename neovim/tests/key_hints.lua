-- Run: nvim --headless '+luafile tests/key_hints.lua'
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd('cquit 1') end
end
local function pause(ms) vim.defer_fn(resume, ms); coroutine.yield() end
local function popup()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'wk' then return true end
  end
  return false
end
runner = coroutine.create(function()
  vim.cmd.enew()
  local invoked = 0
  vim.keymap.set('n', '<leader>zx', function() invoked = invoked + 1 end, { desc = 'Test shortcut' })
  pause(200)
  for _, enabled in ipairs({ false, true, false, true, false }) do
    if enabled or invoked > 0 then vim.api.nvim_input('?'); pause(150) end
    vim.api.nvim_input(' ')
    pause(150)
    assert(popup() == enabled, 'Wrong popup visibility: expected ' .. tostring(enabled))
    vim.api.nvim_input('<Esc>')
    pause(100)
    vim.api.nvim_input(' zx')
    pause(400)
    assert(not popup(), 'Popup remained after completing shortcut')
  end
  assert(invoked == 5, 'Shortcuts failed with hints enabled/disabled')
  print('PASS key hints: default off, repeated ? toggles, real popup visibility, shortcuts still execute')
  vim.cmd('qa!')
end)
vim.schedule(resume)
