local M = {}

-- Pick a branch and show HEAD's changes since diverging from it, replacing the current branch comparison in place.
function M.pick()
  local view = require('diffview.lib').get_current_view()
  local toplevel = view and view.adapter.ctx.toplevel or vim.fn.getcwd()
  local actions, action_state = require('telescope.actions'), require('telescope.actions.state')
  require('telescope.builtin').git_branches({
    cwd = toplevel,
    prompt_title = 'Compare against branch',
    attach_mappings = function(prompt_bufnr, map)
      -- Selection only: disable the picker's track/rebase/create/switch/delete/merge shortcuts.
      for _, key in ipairs({ '<C-t>', '<C-r>', '<C-a>', '<C-s>', '<C-d>', '<C-y>' }) do
        map({ 'i', 'n' }, key, function() end)
      end
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not entry then return end
        local rev_arg = entry.value .. '...HEAD'
        if view and view.rev_arg and view.rev_arg:match('%.%.%.HEAD$') then
          require('diff_refresh').reopen(view, rev_arg)
        else
          require('diffview').open({ '-C' .. toplevel, rev_arg, '--imply-local' })
        end
      end)
      return true
    end,
  })
end

-- Clicking the "Showing changes for:" section of a Diffview file panel opens the picker.
-- The section is rendered last and only for revision comparisons, not for Current Changes.
function M.click()
  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= 0 and mouse.line > 0 then
    local buf = vim.api.nvim_win_get_buf(mouse.winid)
    if vim.bo[buf].filetype == 'DiffviewFiles' then
      local lines = vim.api.nvim_buf_get_lines(buf, 0, mouse.line, false)
      if lines[#lines] ~= '' and vim.list_contains(lines, 'Showing changes for:') then
        vim.schedule(M.pick)
        return ''
      end
    end
  end
  return '<LeftMouse>'
end

return M
