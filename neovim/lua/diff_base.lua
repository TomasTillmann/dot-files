local M = {}

-- Space gb without a detectable parent branch: pick a branch and list HEAD's changes since diverging from it (lua/git_view.lua).
function M.pick()
  local toplevel = require('git_view').root()
  if not toplevel then return end
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
        if entry then require('git_view').against(entry.value) end
      end)
      return true
    end,
  })
end

return M
