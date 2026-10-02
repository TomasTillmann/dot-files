-- Run: nvim --headless '+luafile tests/autosave.lua'
vim.schedule(function()
  local notify = vim.notify
  local ok, err = xpcall(function()
    local root = vim.fn.tempname() .. '-nvim-autosave'
    vim.fn.mkdir(root, 'p')
    root = assert(vim.uv.fs_realpath(root))
    vim.cmd.cd(vim.fn.fnameescape(root))

    local function buffer(name)
      local buf
      if name then
        local path = root .. '/' .. name
        if not name:find('/') then vim.fn.writefile({ 'original' }, path) end
        buf = vim.fn.bufadd(path)
        vim.fn.bufload(buf)
      else
        buf = vim.api.nvim_create_buf(true, false)
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'edited' })
      return buf
    end

    local current = buffer('current.txt')
    local failed = buffer('missing-parent/failure.txt')
    local hidden = buffer('hidden.txt') -- Created after the failing buffer: it must still save.
    local unchanged = buffer('unchanged.txt')
    vim.api.nvim_buf_set_lines(unchanged, 0, -1, false, { 'original' })
    vim.bo[unchanged].modified = false
    local unnamed = buffer()
    local scratch = buffer('scratch.txt')
    vim.bo[scratch].buftype = 'nofile'
    local readonly = buffer('readonly.txt')
    vim.bo[readonly].readonly = true
    local locked = buffer('locked.txt')
    vim.bo[locked].modifiable = false
    vim.api.nvim_set_current_buf(current)

    local writes, errors = {}, {}
    vim.api.nvim_create_autocmd('BufWritePre', {
      pattern = root .. '/*',
      callback = function(event) writes[event.buf] = (writes[event.buf] or 0) + 1 end,
    })
    vim.notify = function(message, level)
      if level == vim.log.levels.ERROR then errors[#errors + 1] = message end
    end
    vim.api.nvim_exec_autocmds('FocusLost', {})

    for _, buf in ipairs({ current, hidden }) do
      local path = vim.api.nvim_buf_get_name(buf)
      assert(vim.fn.readfile(path)[1] == 'edited' and not vim.bo[buf].modified, 'Edited file was not saved: ' .. path)
      assert(writes[buf] == 1, 'Autosave did not trigger BufWritePre exactly once')
    end
    for _, buf in ipairs({ unchanged, scratch, readonly, locked }) do
      assert(vim.fn.readfile(vim.api.nvim_buf_get_name(buf))[1] == 'original', 'Autosave changed a skipped file')
      assert(not writes[buf], 'Autosave attempted to write a skipped buffer')
    end
    assert(vim.api.nvim_buf_get_lines(scratch, 0, -1, false)[1] == 'edited', 'Autosave changed scratch contents')
    for _, buf in ipairs({ unnamed, readonly, locked, failed }) do
      assert(vim.bo[buf].modified, 'Autosave discarded unsaved changes: ' .. vim.api.nvim_buf_get_name(buf))
    end
    assert(not writes[unnamed], 'Autosave attempted to write an unnamed buffer')
    assert(vim.fn.filereadable(root .. '/missing-parent/failure.txt') == 0, 'Autosave forced a failing write')
    assert(#errors > 0, 'A failed save was not reported as an error')
    assert(vim.api.nvim_get_current_buf() == current, 'Autosave changed the current buffer')
    print('PASS focus-loss autosave: current and hidden files, write hooks, skipped buffers, and visible write failures')
  end, debug.traceback)
  vim.notify = notify
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
  else
    vim.cmd('qa!')
  end
end)
