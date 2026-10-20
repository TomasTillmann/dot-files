-- Run: env -u VIRTUAL_ENV nvim --headless '+luafile tests/code_context.lua'
-- Sticky scroll pins the enclosing class and method; grc lists the functions that call the one under the cursor.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err))); vim.cmd('cquit 1') end
end
local function pause(ms) vim.defer_fn(resume, ms); coroutine.yield() end
local function wait(predicate, message, seconds)
  local deadline = vim.uv.hrtime() + (seconds or 30) * 1e9
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message)
    pause(25)
  end
end
local function keys(text) vim.api.nvim_input(text); pause(50) end

runner = coroutine.create(function()
  assert(not vim.env.VIRTUAL_ENV or vim.env.VIRTUAL_ENV == '', 'Run with VIRTUAL_ENV unset')
  vim.o.columns, vim.o.lines = 120, 30
  local root = vim.fn.tempname() .. '-nvim-code-context'
  vim.fn.mkdir(root, 'p')
  root = assert(vim.uv.fs_realpath(root))
  vim.fn.writefile({ '[project]', 'name = "context"', 'version = "0.0.0"' }, root .. '/pyproject.toml')
  local lines = { 'def target() -> int:', '    return 1', '', '', 'class Service:', '    def handle(self) -> int:', '        total = 0' }
  for i = 1, 60 do lines[#lines + 1] = ('        total += %d'):format(i) end
  vim.list_extend(lines, { '        return total + target()', '', '', 'def other() -> int:', '    return target() + 1' })
  local file = root .. '/service.py'
  vim.fn.writefile(lines, file)
  vim.cmd.cd(vim.fn.fnameescape(root))
  vim.cmd.edit(vim.fn.fnameescape(file))

  -- Deep inside handle, with its header scrolled away: class and method stay pinned at the top.
  vim.api.nvim_win_set_cursor(0, { 50, 8 })
  vim.cmd('normal! zt')
  assert(vim.fn.line('w0') > 6, 'The method header is still on screen')
  local context
  wait(function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.w[win].treesitter_context then
        context = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
        return true
      end
    end
  end, 'Sticky scroll did not appear', 5)
  assert(vim.deep_equal(context, { 'class Service:', '    def handle(self) -> int:' }), 'Sticky scroll shows the wrong scopes: ' .. vim.inspect(context))
  print('PASS sticky scroll: enclosing class and method pinned at the top')

  -- grc on target lists both callers by name.
  local buf = vim.api.nvim_get_current_buf()
  wait(function()
    local client = vim.lsp.get_clients({ bufnr = buf, name = 'ty' })[1]
    return client and client.initialized
  end, 'ty did not attach')
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  keys('grc')
  wait(function() return vim.bo.filetype == 'TelescopePrompt' end, 'grc did not open the callers picker')
  local prompt = vim.api.nvim_get_current_buf()
  local picker = require('telescope.actions.state').get_current_picker(prompt)
  wait(function() return picker.manager and picker.manager:num_results() >= 2 end, 'Callers picker did not list both callers')
  local callers = {}
  for entry in picker.manager:iter() do callers[#callers + 1] = entry.text or entry.value.text end
  table.sort(callers)
  assert(vim.deep_equal(callers, { 'handle', 'other' }), 'Callers picker listed: ' .. vim.inspect(callers))
  require('telescope.actions').close(prompt)
  print('PASS callers: grc lists the calling functions by name')
  vim.cmd('qa!')
end)
vim.schedule(resume)
