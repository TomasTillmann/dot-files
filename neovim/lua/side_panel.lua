local M = {}

-- The window docked against the left edge with a pinned width (Git file/history panel, ...).
local function left_panel()
  local wins = vim.tbl_filter(function(win) return vim.api.nvim_win_get_config(win).relative == '' end, vim.api.nvim_tabpage_list_wins(0))
  if #wins < 2 then return nil end
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_position(win)[2] == 0 and vim.wo[win].winfixwidth then return win end
  end
end

-- Space b: close the left panel whatever it is and wherever the cursor is; in a Git tab, reopen its panel otherwise.
function M.toggle()
  local panel = left_panel()
  local filetype = panel and vim.bo[vim.api.nvim_win_get_buf(panel)].filetype
  local diffview = package.loaded['diffview.lib'] and require('diffview.lib').get_current_view()
  if diffview and (not panel or filetype == 'DiffviewFiles' or filetype == 'DiffviewFileHistory') then
    require('diffview.actions').toggle_files()
  elseif panel then
    vim.api.nvim_win_close(panel, false)
  end
end

return M
