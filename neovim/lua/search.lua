local M = {}
local builtin = require('telescope.builtin')

local function root()
  local path = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  local dir = path ~= '' and vim.fs.dirname(path) or vim.fn.getcwd()
  return vim.fs.root(dir, '.git') or vim.fs.root(dir, { 'pyproject.toml', 'pyrightconfig.json' }) or vim.fn.getcwd()
end

local function editing(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local filetype = vim.bo[buf].filetype
  return vim.api.nvim_win_get_config(win).relative == '' and (vim.bo[buf].buftype == '' or filetype == 'ministarter' or filetype == 'neo-tree' or filetype == 'gitview')
end

-- Telescope target window: the one editing view. From a preview that is the list beside it; from a Git diff the diff closes first.
function M.selection_window()
  local owner = require('preview_pane').owner_of(vim.api.nvim_get_current_win())
  if owner then return owner end
  if not vim.t.diffview_title then return 0 end
  require('git_view').close_diff()
  if editing(0) then return vim.api.nvim_get_current_win() end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if editing(win) then return win end
  end
  vim.cmd.vnew()
  return vim.api.nvim_get_current_win()
end

function M.files() builtin.find_files({ cwd = root() }) end
function M.grep() builtin.live_grep({ cwd = root() }) end
-- Jumps within the current buffer, including diff panes. From Visual mode the prompt starts with the selected text.
function M.buffer()
  local text
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    text = table.concat(vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = mode }), ' ')
    vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
  end
  builtin.current_buffer_fuzzy_find({ default_text = text, get_selection_window = function() return 0 end })
end

local starting = false
function M.types()
  local cwd = root()
  local function show(buf)
    builtin.lsp_dynamic_workspace_symbols({
      bufnr = buf,
      cwd = cwd,
      prompt_title = 'Repository types — start typing a name',
      symbols = { 'Class', 'Interface', 'Struct', 'Enum', 'TypeParameter' },
    })
  end

  -- Workspace requests need an attached buffer, even when invoked from the tree/start screen.
  for _, client in ipairs(vim.lsp.get_clients({ name = 'ty', method = 'workspace/symbol' })) do
    if vim.uv.fs_realpath(client.root_dir) == vim.uv.fs_realpath(cwd) then
      for buf in pairs(client.attached_buffers) do
        if vim.api.nvim_buf_is_loaded(buf) then return show(buf) end
      end
    end
  end
  if starting then return vim.notify('Starting Python type search…') end
  starting = true
  vim.notify('Starting Python type search…')
  vim.system(
    { 'rg', '--files', '--glob', '*.py', '--glob', '*.pyi' },
    { cwd = cwd, text = true, timeout = 10000 },
    vim.schedule_wrap(function(result)
      local file = (result.stdout or ''):match('[^\r\n]+')
      if result.code ~= 0 or not file then
        starting = false
        return vim.notify(result.code > 1 and result.stderr or 'No Python files found in this repository.', vim.log.levels.WARN)
      end
      local buf = vim.fn.bufadd(vim.fs.joinpath(cwd, file))
      local finished, attach = false, nil
      local function finish(err)
        if finished then return end
        finished, starting = true, false
        if attach then vim.api.nvim_del_autocmd(attach) end
        if err then return vim.notify(err, vim.log.levels.ERROR) end
        vim.schedule(function() show(buf) end)
      end
      attach = vim.api.nvim_create_autocmd('LspAttach', {
        buffer = buf,
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('workspace/symbol', buf) then finish() end
        end,
      })
      vim.fn.bufload(buf)
      vim.api.nvim_buf_call(buf, function()
        if vim.bo.filetype == '' then vim.cmd.setfiletype('python') end
      end)
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, method = 'workspace/symbol' })) do
        if client.initialized then finish() end
      end
      vim.defer_fn(function() finish('Python language server did not attach. Check :checkhealth vim.lsp and try again.') end, 15000)
    end)
  )
end

return M
