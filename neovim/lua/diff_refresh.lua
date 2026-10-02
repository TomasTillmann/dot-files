local M = {}

function M.start(view)
  if not view.update_files or not view.adapter:has_local(view.left, view.right) then return end
  local watcher = assert(vim.uv.new_fs_event())
  local timer = assert(vim.uv.new_timer())
  local state = { watcher = watcher, timer = timer, dirty = false, closed = false }
  view.auto_refresh = state
  local base = view.rev_arg and view.rev_arg:match('^(.-)%.%.%.HEAD$')

  local function refresh()
    if state.closed or not state.dirty or state.checking then return end
    if not vim.api.nvim_tabpage_is_valid(view.tabpage) or vim.api.nvim_get_current_tabpage() ~= view.tabpage then return end
    if not view.ready or view.navigating_hunks or vim.api.nvim_get_mode().mode ~= 'n' then return end
    if state.refs_dirty then
      state.refs_dirty, state.checking = false, true
      vim.system({ 'git', '-C', view.adapter.ctx.toplevel, 'merge-base', base, 'HEAD' }, { text = true }, vim.schedule_wrap(function(result)
        state.checking = false
        if state.closed then return end
        if result.code == 0 then
          state.base = vim.trim(result.stdout)
        else
          vim.notify('Could not refresh branch comparison: ' .. vim.trim(result.stderr), vim.log.levels.ERROR)
        end
        refresh()
      end))
      return
    end
    state.dirty = false
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tabpage)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == '' and not vim.bo[buf].modified then vim.cmd('silent checktime ' .. buf) end
    end
    if state.base and state.base ~= view.left.commit then
      -- Reopening also replaces cached revision buffers for files whose paths did not change.
      local index = vim.api.nvim_tabpage_get_number(view.tabpage)
      local args = { '-C' .. view.adapter.ctx.toplevel, view.rev_arg, '--imply-local' }
      if view.cur_entry then args[#args + 1] = '--selected-file=' .. view.cur_entry.path end
      if view.options.show_untracked ~= nil then args[#args + 1] = '--untracked-files=' .. tostring(view.options.show_untracked) end
      if #view.path_args > 0 then args[#args + 1] = '--'; vim.list_extend(args, view.path_args) end
      require('diffview').open(args)
      local reopened = vim.api.nvim_get_current_tabpage()
      if reopened == view.tabpage then return end -- Keep the old view if opening failed.
      vim.api.nvim_set_current_tabpage(view.tabpage)
      require('diffview').close()
      vim.api.nvim_set_current_tabpage(reopened)
      vim.cmd('tabmove ' .. (index - 1))
      require('tabline').select(index)
      return
    end
    view:update_files()
  end
  -- Coalesce agent write bursts; there is no periodic Git polling.
  local function schedule()
    if not state.closed and state.dirty then timer:start(300, 0, vim.schedule_wrap(refresh)) end
  end
  local ok, err = watcher:start(view.adapter.ctx.toplevel, { recursive = true }, function(error, path)
    if error or state.closed then return end
    if path and (path:match('^%.git/') or path == '.git' or path:match('^%.venv/') or path:match('^node_modules/')) then return end
    state.dirty = true
    schedule()
  end)
  if not ok then
    M.stop(view)
    vim.notify('Could not watch Git working tree: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  state.git_watcher = assert(vim.uv.new_fs_event())
  local watching, watch_error = state.git_watcher:start(view.adapter.ctx.dir, { recursive = true }, function(error, path)
    if error or state.closed then return end
    if path and (path:match('%.lock$') or not (path == 'index' or path == 'HEAD' or path == 'packed-refs' or path:match('^refs/'))) then return end
    state.dirty = true
    if base and path ~= 'index' then state.refs_dirty = true end
    schedule()
  end)
  if not watching then vim.notify('Could not watch Git metadata: ' .. tostring(watch_error), vim.log.levels.ERROR) end
  state.autocmd = vim.api.nvim_create_autocmd({ 'TabEnter', 'FocusGained', 'TermLeave', 'InsertLeave', 'CursorHold' }, {
    callback = function(event)
      if event.event == 'TabEnter' or event.event == 'FocusGained' or event.event == 'TermLeave' then
        state.dirty = true
        if base then state.refs_dirty = true end
      end
      schedule()
    end,
  })
end

function M.stop(view)
  local state = view.auto_refresh
  if not state then return end
  state.closed = true
  state.watcher:stop(); state.watcher:close()
  if state.git_watcher then state.git_watcher:stop(); state.git_watcher:close() end
  state.timer:stop(); state.timer:close()
  if state.autocmd then vim.api.nvim_del_autocmd(state.autocmd) end
  view.auto_refresh = nil
end

return M
