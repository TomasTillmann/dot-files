-- Run with the active config: env -u VIRTUAL_ENV nvim --headless '+luafile tests/search.lua'
-- Real mappings, Telescope pickers, ripgrep, and ty; only temporary projects are written.
local runner
local function resume()
  local ok, err = coroutine.resume(runner)
  if not ok then
    vim.api.nvim_err_writeln(debug.traceback(runner, tostring(err)))
    vim.api.nvim_err_writeln('LSP log: ' .. vim.lsp.log.get_filename())
    vim.cmd('cquit 1')
  end
end
local function wait_for(predicate, message, timeout)
  local deadline = vim.uv.hrtime() + (timeout or 15000) * 1000000
  while not predicate() do
    assert(vim.uv.hrtime() < deadline, message .. ': ' .. vim.v.errmsg .. ' [mode=' .. vim.api.nvim_get_mode().mode .. ', filetype=' .. vim.bo.filetype .. ']')
    vim.defer_fn(resume, 25)
    coroutine.yield()
  end
end

runner = coroutine.create(function()
  assert(not vim.env.VIRTUAL_ENV or vim.env.VIRTUAL_ENV == '', 'Run with VIRTUAL_ENV unset')
  assert(#vim.lsp.get_clients({ name = 'ty' }) == 0, 'Start with no Python files open')
  for _, key in ipairs({ 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR' }) do
    assert(not vim.env[key] or vim.env[key] == '', 'Run with ' .. key .. ' unset')
  end
  vim.o.columns, vim.o.lines = 160, 50
  local state = require('telescope.actions.state')
  local leader = vim.g.mapleader or '\\'
  local expected_keys = { [leader .. 'sf'] = true, [leader .. 'st'] = true, [leader .. 'ss'] = true, [leader .. 'sg'] = true }
  for key in pairs(expected_keys) do
    local map = vim.fn.maparg(key, 'n', false, true)
    assert(map.buffer == 0 and type(map.callback) == 'function', 'Missing global mapping: ' .. key)
  end
  for _, map in ipairs(vim.api.nvim_get_keymap('n')) do
    local lhs = map.lhs:gsub('<Space>', ' ')
    if lhs:sub(1, #leader + 1) == leader .. 's' then assert(expected_keys[lhs], 'Unexpected search mapping: ' .. lhs) end
  end

  local function command(argv, cwd)
    local result = vim.system(argv, { cwd = cwd, text = true }):wait(10000)
    assert(result.code == 0, table.concat(argv, ' ') .. ': ' .. (result.stderr or 'failed'))
    return vim.trim(result.stdout or '')
  end
  local function write(path, lines) assert(vim.fn.writefile(lines, path) == 0, 'Could not write ' .. path) end
  local function current_picker()
    if vim.bo.filetype ~= 'TelescopePrompt' then return nil end
    local ok, picker = pcall(state.get_current_picker, vim.api.nvim_get_current_buf())
    return ok and picker or nil
  end
  local function entries(picker)
    local found = {}
    if picker.manager then
      for entry in picker.manager:iter() do
        found[#found + 1] = entry
      end
    end
    return found
  end
  local function invoke(suffix)
    vim.api.nvim_input('<Esc>')
    wait_for(function() return vim.api.nvim_get_mode().mode == 'n' end, 'Search requires Normal mode')
    vim.api.nvim_input(leader .. suffix)
    wait_for(function() return current_picker() and vim.api.nvim_get_mode().mode == 'i' end, suffix .. ' did not open a picker', 30000)
    return current_picker()
  end
  local function query(text)
    vim.api.nvim_input(text)
    wait_for(function() return state.get_current_line() == text end, 'Prompt did not receive ' .. text)
  end
  local function close(picker, original)
    vim.api.nvim_input('<Esc><Esc>')
    wait_for(function() return not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) end, 'Picker did not close')
    assert(vim.api.nvim_get_current_buf() == original, 'Cancel changed the original buffer')
  end
  local function path(entry, root)
    local name = entry.path or entry.filename
    return name and vim.fs.normalize(name:sub(1, 1) == '/' and name or root .. '/' .. name)
  end

  local base = vim.fn.tempname() .. '-nvim-search'
  vim.fn.mkdir(base, 'p')
  base = assert(vim.uv.fs_realpath(base))
  print('Search integration fixtures: ' .. base)
  local clients = {}
  for _, name in ipairs({ 'Alpha', 'Beta' }) do
    local root = base .. '/' .. name:lower()
    vim.fn.mkdir(root .. '/src/nested', 'p')
    command({ 'git', 'init', '-q' }, root)
    write(root .. '/pyproject.toml', { '[project]', 'name = "search-' .. name:lower() .. '"', 'version = "0.0.0"' })
    write(root .. '/src/bootstrap.py', { '# search_repo_token other-file-only' })
    write(root .. '/src/nested/models.py', { '# search_repo_token other-file-only' })
    local files = vim.split(command({ 'rg', '--files', '--glob', '*.py', '--glob', '*.pyi' }, root), '\n', { trimempty = true })
    assert(#files == 2, 'Expected two source files')
    -- Put the target in the file rg lists second, so the bootstrap cannot open it first.
    local target = root .. '/' .. files[2]
    local typename = 'Search' .. name .. 'UnopenedType'
    write(root .. '/' .. files[1], { '# search_repo_token other-file-only', 'class Bootstrap' .. name .. ':', '    pass' })
    write(target, { '# search_repo_token other-file-only', 'class ' .. typename .. ':', '    pass', '', 'def Search' .. name .. 'Function():', '    pass' })
    vim.cmd.cd(vim.fn.fnameescape(root .. '/src')) -- All repository pickers must climb to the Git root.
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(scratch)
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { 'scratch introduction', 'search_repo_token current-buffer-only', 'scratch end' })
    vim.bo.modified = false
    assert(#vim.lsp.get_clients({ bufnr = scratch }) == 0, 'Scratch unexpectedly has an LSP client')
    assert(vim.fn.bufnr(target) == -1, 'Target was already opened')
    if name == 'Alpha' then assert(#vim.lsp.get_clients({ name = 'ty' }) == 0, 'First type search must start the server') end

    local types = invoke('st')
    assert(types.original_bufnr == scratch, 'Hidden bootstrap replaced the starting buffer')
    assert(vim.fs.normalize(types.cwd) == root, 'Type picker missed the Git root')
    query('Search')
    wait_for(function()
      local rows = entries(types)
      return #rows == 1 and state.get_selected_entry() == rows[1] and path(rows[1], root) == target and rows[1].symbol_name == typename
    end, 'Live type results did not find only the unopened class in ' .. name, 30000)
    local rendered = table.concat(vim.api.nvim_buf_get_lines(types.results_bufnr, 0, -1, false), '\n')
    assert(rendered:find(typename, 1, true), 'Type result was not rendered before Enter')
    local client
    for _, candidate in ipairs(vim.lsp.get_clients({ name = 'ty' })) do
      if vim.uv.fs_realpath(candidate.root_dir) == root then client = candidate end
    end
    assert(client and client.initialized, 'Type picker did not initialize this project server')
    clients[#clients + 1] = client.id
    vim.api.nvim_input('<CR>')
    wait_for(function() return vim.api.nvim_buf_get_name(0) == target and vim.api.nvim_win_get_cursor(0)[1] == 2 end, 'Enter did not jump to the selected type')
    assert(vim.api.nvim_win_get_cursor(0)[1] == 2, 'Type jump missed the class declaration')
    vim.api.nvim_set_current_buf(scratch)

    local file_picker = invoke('sf')
    assert(vim.fs.normalize(file_picker.cwd) == root, 'File search missed the Git root')
    query(vim.fs.basename(target))
    wait_for(function()
      local rows = entries(file_picker)
      return #rows == 1 and path(rows[1], root) == target
    end, 'File results did not update while typing')
    close(file_picker, scratch)

    local buffer_picker = invoke('ss')
    query('search_repo_token')
    wait_for(function()
      local rows = entries(buffer_picker)
      return #rows == 1 and rows[1].lnum == 2 and rows[1].text:find('current-buffer-only', 1, true)
    end, 'Current-buffer search did not isolate the scratch-buffer line')
    close(buffer_picker, scratch)

    local grep_picker = invoke('sg')
    assert(vim.fs.normalize(grep_picker.cwd) == root, 'Text search missed the Git root')
    query('search_repo_token')
    wait_for(function() return #entries(grep_picker) == 2 end, 'Repository grep did not return both source files before Enter')
    for _, entry in ipairs(entries(grep_picker)) do
      local filename = path(entry, root)
      assert(filename == root .. '/' .. files[1] or filename == target, 'Grep returned a different repository: ' .. tostring(filename))
      assert(entry.text:find('other-file-only', 1, true), 'Grep included the scratch buffer')
    end
    close(grep_picker, scratch)
    if name == 'Alpha' then
      vim.cmd.edit(vim.fn.fnameescape(root .. '/pyproject.toml'))
      local editor = vim.api.nvim_get_current_win()
      vim.cmd('Neotree filesystem left')
      wait_for(function() return vim.bo.filetype == 'neo-tree' end, 'Neo-tree did not take focus')
      local tree = vim.api.nvim_get_current_win()
      local tree_ready = vim.uv.hrtime() + 250000000
      wait_for(
        function() return vim.uv.hrtime() >= tree_ready and vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(tree)) > 1 end,
        'Neo-tree did not render'
      )
      for _, case in ipairs({
        { key = 'st', query = 'Bootstrap' .. name, target = root .. '/' .. files[1], line = 2 },
        { key = 'sg', query = 'def Search' .. name .. 'Function', target = target, line = 5 },
      }) do
        vim.api.nvim_set_current_win(tree)
        local picker = invoke(case.key)
        query(case.query)
        wait_for(function()
          local rows = entries(picker)
          return #rows == 1 and state.get_selected_entry() == rows[1] and path(rows[1], root) == case.target and rows[1].lnum == case.line
        end, case.key .. ' from Neo-tree did not find the expected location')
        vim.api.nvim_input('<CR>')
        wait_for(function() return vim.api.nvim_buf_get_name(0) == case.target end, case.key .. ' from Neo-tree did not open the target')
        -- Neo-tree redirects foreign buffers asynchronously; check the final location after that redirect.
        local settled = vim.uv.hrtime() + 250000000
        wait_for(function() return vim.uv.hrtime() >= settled end, 'Window events did not settle')
        assert(vim.api.nvim_get_current_win() == editor, case.key .. ' did not use the existing editing window')
        assert(
          vim.api.nvim_buf_get_name(0) == case.target and vim.api.nvim_win_get_cursor(0)[1] == case.line,
          case.key .. ' from Neo-tree lost the selected line: ' .. vim.inspect(vim.api.nvim_win_get_cursor(0))
        )
        assert(vim.api.nvim_win_is_valid(tree) and vim.bo[vim.api.nvim_win_get_buf(tree)].filetype == 'neo-tree', case.key .. ' replaced or closed Neo-tree')
        vim.cmd.edit(vim.fn.fnameescape(root .. '/pyproject.toml'))
      end
      vim.cmd('Neotree close')
      print('PASS Neo-tree: type and grep Enter preserve the editing window, exact line, and tree')
    end
    print('PASS ' .. name .. ': global keys, hidden LSP bootstrap, live type/file/buffer/repository results, type Enter jump')
  end
  assert(clients[1] ~= clients[2], 'Type search reused the other repository language server')
  print('PASS search integration: four shortcuts and two isolated Git projects')
  vim.cmd('qa!')
end)
vim.schedule(resume)
