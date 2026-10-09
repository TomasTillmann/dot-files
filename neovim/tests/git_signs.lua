-- Run with the active config: env -u VIRTUAL_ENV nvim --headless '+luafile tests/git_signs.lua'
-- Uses a disposable repository in Neovim's temporary directory.
vim.schedule(function()
  local ok, err = xpcall(function()
    local function git(dir, ...)
      local result = vim.system({ 'git', '-C', dir, ... }, { text = true }):wait()
      assert(result.code == 0, 'git ' .. table.concat({ ... }, ' ') .. ': ' .. (result.stderr or ''))
      return result.stdout
    end
    local repo = vim.fn.tempname() .. '-nvim-gitsigns'
    vim.fn.mkdir(repo, 'p')
    repo = assert(vim.uv.fs_realpath(repo))
    git(repo, 'init', '-q')
    git(repo, 'config', 'user.email', 'test@example.invalid')
    git(repo, 'config', 'user.name', 'Test')
    local lines = {}
    for i = 1, 30 do lines[i] = 'line ' .. i end
    assert(vim.fn.writefile(lines, repo .. '/file.txt') == 0)
    git(repo, 'add', 'file.txt')
    git(repo, 'commit', '-q', '-m', 'init')
    lines[5], lines[20] = 'changed 5', 'changed 20'
    assert(vim.fn.writefile(lines, repo .. '/file.txt') == 0)

    vim.cmd.edit(vim.fn.fnameescape(repo .. '/file.txt'))
    local buf = vim.api.nvim_get_current_buf()
    assert(
      vim.wait(10000, function()
        local hunks = require('gitsigns').get_hunks(buf)
        return hunks and #hunks == 2
      end, 50),
      'gitsigns did not report both changes'
    )
    -- Signs are drawn by a decoration provider, so they need a redraw.
    assert(
      vim.wait(5000, function()
        vim.cmd.redraw()
        return #vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { type = 'sign' }) >= 2
      end, 50),
      'Change markers missing from the sign column'
    )

    for _, key in ipairs({ ']h', '[h', ' gp', ' gs', ' gr', ' gl' }) do
      local lhs = key:gsub('^ ', '<leader>')
      assert(vim.fn.maparg(lhs, 'n', false, true).buffer == 1, 'Missing buffer mapping ' .. lhs)
    end

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(vim.keycode(']h'), 'x', false)
    assert(vim.wait(3000, function() return vim.fn.line('.') == 5 end, 20), 'Next-change jump did not reach line 5')

    vim.api.nvim_feedkeys(vim.keycode('<leader>gs'), 'x', false)
    assert(vim.wait(5000, function() return git(repo, 'diff', '--cached', '--name-only'):find('file.txt', 1, true) ~= nil end, 50), 'Staging the change failed')
    assert(git(repo, 'diff', '--cached'):find('changed 5', 1, true) and not git(repo, 'diff', '--cached'):find('changed 20', 1, true), 'Staged more than the hunk under the cursor')
    print('PASS gitsigns: change markers, next-change jump, hunk staging, buffer keymaps')
  end, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
  else
    vim.cmd('qa!')
  end
end)
