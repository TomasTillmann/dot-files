-- Run with the active config: env -u VIRTUAL_ENV nvim --headless '+luafile tests/languages.lua'
-- Fixtures use Neovim's temporary directory and are removed when Neovim exits.
vim.schedule(function()
  local ok, err = xpcall(function()
    local base = vim.fn.tempname() .. '-nvim-languages'
    vim.fn.mkdir(base, 'p')
    base = assert(vim.uv.fs_realpath(base))
    local function write(path, lines) assert(vim.fn.writefile(lines, path) == 0, 'Could not write ' .. path) end

    -- Lua: lua_ls attaches and lazydev supplies Neovim API types.
    write(base .. '/.stylua.toml', {})
    write(base .. '/probe.lua', { 'local buf = vim.api.nvim_get_current_buf()', 'return buf' })
    vim.cmd.edit(vim.fn.fnameescape(base .. '/probe.lua'))
    local buf = vim.api.nvim_get_current_buf()
    local client
    assert(
      vim.wait(30000, function()
        client = vim.lsp.get_clients({ bufnr = buf, name = 'lua_ls' })[1]
        return client ~= nil and client.initialized
      end, 50),
      'lua_ls did not attach'
    )
    local params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = 0, character = 22 } }
    assert(
      vim.wait(30000, function()
        local response = client:request_sync('textDocument/hover', params, 5000, buf)
        local text = response and response.result and vim.inspect(response.result.contents) or ''
        return text:find('integer', 1, true) ~= nil
      end, 500),
      'lua_ls hover did not know the Neovim API (lazydev)'
    )
    print('PASS Lua: lua_ls attached with Neovim API types')

    -- Tree-sitter highlighting for common project files.
    local files = {
      ['pyproject.toml'] = { '[project]', 'name = "x"' },
      ['ci.yaml'] = { 'jobs:', '  test: {}' },
      ['data.json'] = { '{"a": 1}' },
      ['Dockerfile'] = { 'FROM python:3.12' },
      ['run.sh'] = { '#!/bin/bash', 'echo hi' },
      ['COMMIT_EDITMSG'] = { 'Subject line', '', 'Body' },
    }
    for name, lines in pairs(files) do
      write(base .. '/' .. name, lines)
      vim.cmd.edit(vim.fn.fnameescape(base .. '/' .. name))
      if name == 'COMMIT_EDITMSG' then vim.cmd.setfiletype('gitcommit') end
      assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], 'No Tree-sitter highlighting for ' .. name .. ' (' .. vim.bo.filetype .. ')')
    end
    print('PASS Tree-sitter: toml, yaml, json, dockerfile, bash, gitcommit')

    -- Python formatting prefers the project's own Ruff.
    vim.fn.mkdir(base .. '/proj/.venv/bin', 'p')
    write(base .. '/proj/.venv/bin/ruff', { '#!/bin/sh' })
    vim.fn.setfperm(base .. '/proj/.venv/bin/ruff', 'rwxr-xr-x')
    write(base .. '/proj/app.py', { 'x = 1' })
    vim.cmd.edit(vim.fn.fnameescape(base .. '/proj/app.py'))
    local info = require('conform').get_formatter_info('ruff_format', vim.api.nvim_get_current_buf())
    assert(info.command == base .. '/proj/.venv/bin/ruff', 'Formatter did not use the project Ruff: ' .. tostring(info.command))
    print('PASS Formatting: project .venv Ruff preferred')
  end, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
  else
    vim.cmd('qa!')
  end
end)
