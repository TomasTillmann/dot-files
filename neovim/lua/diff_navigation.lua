local M = {}

local function hunks()
  vim.cmd('diffupdate')
  local starts, inside = {}, false
  local count = vim.api.nvim_buf_line_count(0)
  for line = 1, count do
    local changed = vim.fn.diff_hlID(line, 1) ~= 0 or vim.fn.diff_filler(line) > 0
    if changed and not inside then starts[#starts + 1] = line end
    inside = changed
  end
  if vim.fn.diff_filler(count + 1) > 0 and not inside then starts[#starts + 1] = count end
  return starts
end

function M.jump(direction)
  local view = require('diffview.lib').get_current_view()
  if not view or not vim.wo.diff then
    vim.cmd.normal({ direction > 0 and ']c' or '[c', bang = true })
    return
  end
  if view.navigating_hunks then return end
  local repetitions = vim.v.count1
  view.navigating_hunks = true
  local async = require('diffview.async')
  async.void(function()
    local ok, err = xpcall(function()
      local files = {}
      if view.files then
        files = view.panel:ordered_file_list() -- Follows the panel's tree order.
      else
        for _, entry in ipairs(view.panel.entries) do
          vim.list_extend(files, entry.files)
        end
      end
      for _ = 1, repetitions do
        local row = vim.fn.line('.')
        vim.cmd.normal({ direction > 0 and ']c' or '[c', bang = true })
        if vim.fn.line('.') == row then
          local index
          for i, file in ipairs(files) do if file == view.cur_entry then index = i; break end end
          if not index then return end
          for step = 1, #files do
            if not vim.api.nvim_tabpage_is_valid(view.tabpage) or vim.api.nvim_get_current_tabpage() ~= view.tabpage then return end
            local file = files[(index - 1 + direction * step) % #files + 1]
            async.await(view:set_file(file, true))
            if vim.api.nvim_get_current_tabpage() ~= view.tabpage then return end
            local starts = hunks()
            if #starts > 0 then
              vim.api.nvim_win_set_cursor(0, { direction > 0 and starts[1] or starts[#starts], 0 })
              vim.cmd('normal! zz')
              break
            end
          end
        end
      end
    end, debug.traceback)
    view.navigating_hunks = nil
    if not ok then vim.notify(err, vim.log.levels.ERROR) end
  end)()
end

return M
