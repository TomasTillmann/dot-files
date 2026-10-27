-- Run: env -u VIRTUAL_ENV nvim --headless '+luafile tests/git_parent.lua'
-- Space gb's parent-branch detection in a disposable repository: the reflog's creating branch, an explicit start point,
-- a rebased branch and an expired reflog falling back to the branch sharing the most history.
local ok, err = xpcall(function()
  local root = vim.fn.tempname() .. '-git-parent'
  vim.fn.mkdir(root, 'p')
  local function git(...)
    local result = vim.system({ 'git', '-C', root, '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', ... }, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  local function commit(name)
    vim.fn.writefile({ name }, root .. '/' .. name .. '.txt')
    git('add', '.'); git('commit', '-qm', name)
  end
  local function parent(expected, message)
    local found = require('git_view').parent_branch(root)
    assert(found == expected, message .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(found))
  end
  git('init', '-q', '-b', 'main')
  git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
  commit('base'); git('update-ref', 'refs/remotes/origin/main', 'HEAD')
  git('switch', '-qc', 'release'); commit('release')
  git('switch', '-qc', 'side'); commit('side')
  git('switch', '-q', 'release')
  git('switch', '-qc', 'feature'); commit('feature')
  -- release moving on doesn't change where feature came from.
  git('switch', '-q', 'release'); commit('release-later')
  git('switch', '-q', 'feature')
  parent('release', 'Branch created by switching from release')
  git('switch', '-qc', 'explicit', 'side'); commit('explicit')
  parent('side', 'Branch created with an explicit start point')
  -- After a rebase the reflog's branch no longer applies; the closest fork point does.
  git('switch', '-qc', 'moved', 'release'); commit('moved')
  git('-c', 'rebase.updateRefs=false', 'rebase', '-q', 'side')
  parent('side', 'Rebased branch')
  git('switch', '-q', 'feature')
  git('reflog', 'expire', '--expire=now', '--all')
  parent('release', 'Expired reflog')
  git('switch', '-q', 'main')
  parent(nil, 'Branch without commits of its own')
  vim.fn.delete(root, 'rf')
end, debug.traceback)
if not ok then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end
print('git parent ok')
vim.cmd('qall!')
