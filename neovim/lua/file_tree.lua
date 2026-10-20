local M = {}

-- Space e: show the folder tree full-window in place of the current buffer, revealing the current file; Space e in the tree goes back.
function M.toggle()
  if vim.bo.filetype == 'neo-tree' then
    require('neo-tree.command').execute({ action = 'close' })
    return
  end
  -- From a Git tab the tree opens in the Panel tab's editing window instead of replacing a diff pane.
  local win = require('search').selection_window()
  if win ~= 0 then vim.api.nvim_set_current_win(win) end
  local file = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  local cwd = vim.fn.getcwd()
  local dir = cwd
  if file ~= '' and not vim.startswith(file, cwd .. '/') then dir = vim.fs.root(file, '.git') or vim.fs.dirname(file) end
  require('neo-tree.command').execute({ source = 'filesystem', position = 'current', dir = dir, reveal_file = file ~= '' and file or nil })
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
