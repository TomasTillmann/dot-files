local M = {}

-- Space e: show the folder tree full-window in place of the current buffer, revealing the current file; Space e in the tree goes back.
function M.toggle()
  local from_preview = require('preview_pane').owner_of(vim.api.nvim_get_current_win())
  if from_preview then vim.api.nvim_set_current_win(from_preview) end
  if vim.bo.filetype == 'neo-tree' then
    require('neo-tree.command').execute({ action = 'close' })
    return
  end
  local file = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  if vim.startswith(file, 'diffview://') then file = '' end
  -- A staged diff shows the index on both sides, so the file comes from the diff's entry.
  local view = file == '' and vim.t.diffview_title and require('diffview.lib').get_current_view()
  if view and view.cur_entry then file = view.cur_entry.absolute_path end
  -- From a Git diff the diff closes first, so the tree opens in the one editing view, on the file of the diff.
  local win = require('search').selection_window()
  if win ~= 0 then vim.api.nvim_set_current_win(win) end
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

-- Live preview: while the tree is shown, the file (or folder listing) under the cursor appears read-only on the right (lua/preview_pane.lua).
M.preview_enabled = true
local pane = require('preview_pane')
local timer = vim.uv.new_timer()
local max_bytes = 512 * 1024

local function read(path, stat)
  if stat.type == 'directory' then
    local dirs, files = {}, {}
    for name, kind in vim.fs.dir(path) do
      if name ~= '.git' then table.insert(kind == 'directory' and dirs or files, kind == 'directory' and name .. '/' or name) end
    end
    table.sort(dirs); table.sort(files)
    local lines = vim.list_extend(dirs, files)
    return #lines > 0 and lines or { '(empty folder)' }
  end
  local f = io.open(path, 'rb')
  if not f then return { '(cannot read file)' } end
  local data = f:read(max_bytes) or ''
  f:close()
  if data:find('\0', 1, true) then return { '(binary file)' } end
  local lines = vim.split(data, '\r?\n')
  if stat.size > max_bytes then lines[#lines] = nil; table.insert(lines, '… (first 512 KB shown)') end
  return lines
end

local function is_tree(win) return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'neo-tree' end

-- Enter in the preview opens the real file in the tree's window at the same line.
local function open_previewed(tree_win, cursor)
  local path = pane.key(tree_win)
  if not path or vim.fn.isdirectory(path) == 1 then return end
  vim.api.nvim_set_current_win(tree_win)
  vim.cmd.edit(vim.fn.fnameescape(path))
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)
  vim.cmd.normal({ 'zz', bang = true })
end

local function update(tree_win)
  if not M.preview_enabled or not vim.api.nvim_win_is_valid(tree_win) or not is_tree(tree_win) then return end
  local ok, state = pcall(require('neo-tree.sources.manager').get_state, 'filesystem', nil, tree_win)
  if not ok or not state.tree or state.winid ~= tree_win then return end
  local got, node = pcall(state.tree.get_node, state.tree)
  if not got or not node or not node.path or node.type == 'message' then return end
  if pane.key(tree_win) == node.path then return end
  local stat = vim.uv.fs_stat(node.path)
  if not stat then return end
  local lines = read(node.path, stat)
  pane.show(tree_win, node.path, lines, {
    title = vim.fn.fnamemodify(node.path, ':~:.'),
    filetype = stat.type == 'file' and vim.filetype.match({ filename = node.path, contents = lines }) or nil,
    keep = is_tree,
    on_enter = open_previewed,
  })
end

-- Called for every tree buffer: the preview follows the cursor, briefly debounced so holding j stays smooth.
function M.attach_preview(buf)
  if vim.b[buf].file_tree_preview_attached then return end
  vim.b[buf].file_tree_preview_attached = true
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      timer:stop()
      timer:start(30, 0, vim.schedule_wrap(function() update(win) end))
    end,
  })
end

-- After each render: a freshly opened tree has no nodes until its first render, so the preview starts here.
function M.after_render(state)
  if state.name == 'filesystem' and state.winid and vim.api.nvim_win_is_valid(state.winid) then update(state.winid) end
end

-- P in the tree: turn the live preview off or back on.
function M.toggle_preview(state)
  M.preview_enabled = not M.preview_enabled
  if M.preview_enabled then update(state.winid) else pane.close(state.winid) end
end

function M.scroll_preview(state, key) pane.scroll(state.winid, key) end
function M.focus_preview(state) pane.focus(state.winid) end

return M
