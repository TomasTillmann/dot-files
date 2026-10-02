-- Run with the active config: env -u VIRTUAL_ENV nvim --headless '+luafile tests/python_lsp.lua'
-- Fixtures use Neovim's temporary directory and are removed when Neovim exits.
vim.schedule(function()
  local ok, err = xpcall(function()
    assert(not vim.env.VIRTUAL_ENV or vim.env.VIRTUAL_ENV == '', 'Run with VIRTUAL_ENV unset')
    assert(vim.fn.executable('uv') == 1, 'uv is required to create real test environments')

    local function command(argv)
      local result = vim.system(argv, { text = true }):wait(30000)
      assert(result.code == 0, table.concat(argv, ' ') .. ': ' .. (result.stderr or 'failed'))
      return vim.trim(result.stdout or '')
    end

    local function write(path, lines) assert(vim.fn.writefile(lines, path) == 0, 'Could not write ' .. path) end

    local base = vim.fn.tempname() .. '-nvim-python'
    vim.fn.mkdir(base, 'p')
    base = assert(vim.uv.fs_realpath(base))
    vim.cmd.cd(vim.fn.fnameescape(base)) -- Deliberately outside either Python project.
    print('Python integration fixtures: ' .. base)
    local verified = {}

    for _, name in ipairs({ 'alpha', 'beta' }) do
      local root = base .. '/' .. name
      local module = 'nvim_venv_probe_' .. name
      vim.fn.mkdir(root, 'p')
      write(root .. '/pyproject.toml', { '[project]', 'name = "nvim-test-' .. name .. '"', 'version = "0.0.0"' })
      command({ 'uv', 'venv', '--no-project', '--no-python-downloads', root .. '/.venv' })
      local site = command({ root .. '/.venv/bin/python', '-c', 'import sysconfig; print(sysconfig.get_path("purelib"))' })
      local dependency = site .. '/' .. module .. '.py'
      write(dependency, { 'def token() -> int:', '    return 42' })
      local source_root = root
      if name == 'beta' then
        source_root = root .. '/packages/member'
        vim.fn.mkdir(source_root, 'p')
        write(source_root .. '/pyproject.toml', { '[project]', 'name = "nested-member"', 'version = "0.0.0"' })
      end
      write(source_root .. '/models.py', {
        'class Widget:',
        '    def __init__(self, name: str) -> None:',
        '        self.name = name',
        '',
        'def make_widget() -> Widget:',
        '    return Widget("model reference")',
      })
      local source = {
        'from models import Widget',
        'from ' .. module .. ' import token',
        '',
        'widget: Widget = Widget("demo")',
        'label: str = widget.name',
        'answer: int = token()',
        'broken: int = "intentional type mismatch"',
      }
      write(source_root .. '/app.py', source)
      vim.cmd.edit(vim.fn.fnameescape(source_root .. '/app.py'))
      local buf = vim.api.nvim_get_current_buf()
      local client
      assert(
        vim.wait(30000, function()
          local clients = vim.lsp.get_clients({ bufnr = buf, name = 'pyright' })
          client = clients[1]
          return #clients == 1 and client.initialized
        end, 50),
        'Pyright did not attach to ' .. root
      )
      assert(vim.uv.fs_realpath(client.config.root_dir) == root, 'Incorrect LSP root: ' .. tostring(client.config.root_dir))
      assert(client.settings.python.pythonPath == root .. '/.venv/bin/python', 'Incorrect project interpreter')
      assert(vim.fn.getcwd() == base, 'Opening a file unexpectedly changed cwd')

      local function request(method, params)
        local response, request_error = client:request_sync(method, params, 15000, buf)
        assert(response, method .. ': ' .. tostring(request_error))
        assert(not response.err, method .. ': ' .. vim.inspect(response.err))
        assert(response.result ~= nil and response.result ~= vim.NIL, method .. ': empty response')
        return response.result
      end

      local function position(line, word)
        return {
          textDocument = { uri = vim.uri_from_bufnr(buf) },
          position = { line = line - 1, character = assert(source[line]:find(word, 1, true)) - 1 },
        }
      end

      local function paths(result)
        if result.uri or result.targetUri then result = { result } end
        local found = {}
        for _, location in ipairs(result) do
          local uri = location.uri or location.targetUri or (location.location or {}).uri
          if uri then found[vim.uri_to_fname(uri)] = true end
        end
        return found
      end

      assert(
        vim.wait(30000, function()
          for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
            if diagnostic.lnum == 6 and diagnostic.code == 'reportAssignmentType' then return true end
          end
          return false
        end, 50),
        'Expected type-error diagnostic was not published'
      )
      for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
        assert(
          diagnostic.code ~= 'reportMissingImports' and diagnostic.code ~= 'reportMissingModuleSource',
          'The project .venv import did not resolve: ' .. diagnostic.message
        )
      end

      local hover = request('textDocument/hover', position(5, 'widget'))
      assert(vim.inspect(hover.contents):find('Widget', 1, true), 'Hover did not describe Widget type')
      assert(paths(request('textDocument/definition', position(4, 'Widget')))[source_root .. '/models.py'], 'Definition missed models.py')
      assert(paths(request('textDocument/typeDefinition', position(5, 'widget')))[source_root .. '/models.py'], 'Type definition missed Widget')
      assert(paths(request('textDocument/definition', position(2, 'token')))[dependency], 'Import definition missed this project .venv')

      local reference_params = position(1, 'Widget')
      reference_params.context = { includeDeclaration = false }
      local references = paths(request('textDocument/references', reference_params))
      assert(references[source_root .. '/models.py'] and references[source_root .. '/app.py'], 'References did not span both source files')
      local symbols = request('workspace/symbol', { query = 'Widget' })
      assert(paths(symbols)[source_root .. '/models.py'], 'Workspace symbol search did not find Widget')

      assert(vim.treesitter.highlighter.active[buf], 'Python Tree-sitter highlighting is not active')
      local parser = vim.treesitter.get_parser(buf, 'python')
      assert(parser:parse()[1]:root():type() == 'module', 'Python parser did not parse a module')
      local key = (vim.g.mapleader or '\\') .. 'st'
      local mapping = vim.fn.maparg(key, 'n', false, true)
      assert(mapping.buffer == 0 and type(mapping.callback) == 'function', 'Global type-search key is missing')
      verified[#verified + 1] = { client = client.id, buf = buf, root = root }
      print('PASS ' .. name .. ': root, .venv import, hover, definitions, references, types, diagnostics, Tree-sitter, type-search key')
    end

    assert(verified[1].client ~= verified[2].client, 'Projects unexpectedly share an LSP client')
    for _, project in ipairs(verified) do
      assert(vim.lsp.buf_is_attached(project.buf, project.client), 'Switching projects detached the previous client')
    end
    print('PASS Python integration: two independent .venv projects in one Neovim process')
  end, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.api.nvim_err_writeln('LSP log: ' .. vim.lsp.log.get_filename())
    vim.cmd('cquit 1')
  else
    vim.cmd('qa!')
  end
end)
