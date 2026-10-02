-- Run: nvim --headless '+luafile tests/diagnostics.lua'
vim.schedule(function()
  local ok, err = xpcall(function()
    vim.o.columns = 160
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.txt')
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'warning', 'error', 'hint' })
    vim.bo.modified = false
    local ns = vim.api.nvim_create_namespace('errors-only-test')
    local severity = vim.diagnostic.severity
    vim.diagnostic.set(ns, buf, {
      { lnum = 0, col = 0, end_col = 7, severity = severity.WARN, message = 'hidden-warning-probe' },
      { lnum = 1, col = 0, end_col = 5, severity = severity.ERROR, message = 'visible-error-probe' },
      { lnum = 2, col = 0, end_col = 4, severity = severity.HINT, message = 'hidden-hint-probe' },
    })
    assert(#vim.diagnostic.get(buf) == 3, 'Display settings removed source diagnostics')
    local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
    local visible = 0
    for _, mark in ipairs(marks) do
      local detail = mark[4]
      assert(not detail.virt_text and not detail.virt_lines, 'Diagnostic text was displayed inline')
      if detail.hl_group or detail.sign_text or detail.virt_text or detail.virt_lines then
        visible = visible + 1
        assert(mark[2] == 1, 'A non-error diagnostic was decorated: ' .. vim.inspect(mark))
      end
    end
    assert(visible >= 2, 'Error decorations are missing')
    local float_buf, float_win = vim.diagnostic.open_float({ scope = 'buffer' })
    local text = table.concat(vim.api.nvim_buf_get_lines(float_buf, 0, -1, false), '\n')
    assert(text:find('visible-error-probe', 1, true) and not text:find('hidden-', 1, true), 'Float did not filter warnings/hints')
    vim.api.nvim_win_close(float_win, true)
    local statusline = require('mini.statusline')
    assert(statusline.section_diagnostics({ trunc_width = 0 }) == 'E1', 'Statusline displayed non-error counts')
    vim.diagnostic.enable(false, { bufnr = buf })
    assert(statusline.section_diagnostics({ trunc_width = 0 }) == '', 'Disabled diagnostics still appeared in the statusline')
    vim.diagnostic.enable(true, { bufnr = buf })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.diagnostic.jump({ count = 1 })
    assert(vim.api.nvim_win_get_cursor(0)[1] == 2, 'Diagnostic navigation did not select the error')
    local jump_float
    assert(vim.wait(1000, function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(win).relative ~= '' then jump_float = win; return true end
      end
    end), 'Diagnostic jump did not open its float')
    local jump_text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(jump_float), 0, -1, false), '\n')
    assert(jump_text:find('visible-error-probe', 1, true), 'Diagnostic jump float missed the error')
    vim.api.nvim_win_close(jump_float, true)
    local leader = vim.g.mapleader or '\\'
    local toggle = vim.fn.maparg(leader .. 'q', 'n', false, true).callback
    local editor = vim.api.nvim_get_current_win()
    toggle()
    local list = vim.fn.getloclist(editor, { winid = 0 }).winid
    local items = vim.fn.getloclist(editor)
    assert(list ~= 0 and #items == 1 and items[1].type == 'E', 'Error list did not open with errors only')
    vim.api.nvim_set_current_win(list)
    toggle()
    assert(vim.fn.getloclist(editor, { winid = 0 }).winid == 0, 'Toggle did not close from the list')
    toggle()
    vim.api.nvim_set_current_win(editor)
    toggle()
    assert(vim.fn.getloclist(editor, { winid = 0 }).winid == 0, 'Toggle did not close from the editor')
    vim.diagnostic.reset(ns, buf)
    toggle()
    assert(vim.fn.getloclist(editor, { winid = 0 }).winid ~= 0 and #vim.fn.getloclist(editor) == 0, 'Empty error list did not open')
    toggle()
    local notifications = require('fidget.notification')
    notifications.clear()
    notifications.clear_history()
    vim.notify('hidden-notification-probe', vim.log.levels.WARN)
    vim.notify('visible-notification-probe', vim.log.levels.ERROR)
    local history = vim.inspect(notifications.get_history())
    assert(not history:find('hidden-notification-probe', 1, true), 'Warning notification was retained')
    assert(history:find('visible-notification-probe', 1, true), 'Error notification was suppressed')
    print('PASS errors-only UI: decorations, float, statusline, navigation, error list, and notifications; source diagnostics retained')
  end, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
  else
    vim.cmd('qa!')
  end
end)
