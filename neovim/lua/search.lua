local M = {}
local builtin = require('telescope.builtin')

local function root()
  local path = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  local dir = path ~= '' and vim.fs.dirname(path) or vim.fn.getcwd()
  return vim.fs.root(dir, '.git') or vim.fs.root(dir, { 'pyproject.toml', 'pyrightconfig.json' }) or vim.fn.getcwd()
end

function M.files() builtin.find_files({ cwd = root() }) end
function M.grep() builtin.live_grep({ cwd = root() }) end
function M.buffer() builtin.current_buffer_fuzzy_find() end

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
  for _, client in ipairs(vim.lsp.get_clients({ name = 'pyright', method = 'workspace/symbol' })) do
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
