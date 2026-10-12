local M = {}

-- The window docked against the left edge with a pinned width (file tree, Git file/history panel, ...).
local function left_panel()
  local wins = vim.tbl_filter(function(win) return vim.api.nvim_win_get_config(win).relative == '' end, vim.api.nvim_tabpage_list_wins(0))
  if #wins < 2 then return nil end
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_position(win)[2] == 0 and vim.wo[win].winfixwidth then return win end
  end
end

-- Space b: close the left panel whatever it is and wherever the cursor is; reopen this tab's panel otherwise.
function M.toggle()
  local panel = left_panel()
  local filetype = panel and vim.bo[vim.api.nvim_win_get_buf(panel)].filetype
  local diffview = package.loaded['diffview.lib'] and require('diffview.lib').get_current_view()
  if filetype == 'neo-tree' then
    require('neo-tree.command').execute({ action = 'close' })
  elseif diffview and (not panel or filetype == 'DiffviewFiles' or filetype == 'DiffviewFileHistory') then
    require('diffview.actions').toggle_files()
  elseif panel then
    vim.api.nvim_win_close(panel, false)
  else
    require('neo-tree.command').execute({ action = 'show', source = 'filesystem', position = 'left' })
  end
end

-- Folders Z leaves closed: environments and caches can hold tens of thousands of files.
local heavy = { ['.venv'] = true, venv = true, node_modules = true, __pycache__ = true, ['.ruff_cache'] = true, ['.mypy_cache'] = true, ['.pytest_cache'] = true, ['.tox'] = true }

-- Z in the file tree: open every folder under the cursor, one level scan at a time so heavy folders are never read.
function M.expand_all(state)
  local fs_scan = require('neo-tree.sources.filesystem.lib.fs_scan')
  local start = state.tree:get_node()
  if not start or start.type ~= 'directory' then return end
  state.explicitly_opened_nodes = state.explicitly_opened_nodes or {}
  require('plenary.async').run(function()
    local function expand(id)
      local node = state.tree:get_node(id)
      if not node or node.type ~= 'directory' or (heavy[node.name] and id ~= start:get_id()) then return end
      if not node.loaded then
        fs_scan.get_dir_items_async(state, id, false)
        node = state.tree:get_node(id)
      end
      node:expand()
      state.explicitly_opened_nodes[id] = true
      for _, child in ipairs(state.tree:get_nodes(id)) do expand(child:get_id()) end
    end
    expand(start:get_id())
  end, function() require('neo-tree.ui.renderer').redraw(state) end)
end

return M
