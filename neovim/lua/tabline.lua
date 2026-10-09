local M = {}

function M.render()
  local labels = {}
  for index, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local buf = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))
    local name = vim.t[tab].workspace_title or vim.t[tab].diffview_title or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
    if name == '' then name = '[No Name]' end
    local modified = false
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      modified = modified or vim.bo[vim.api.nvim_win_get_buf(win)].modified
    end
    local highlight = tab == vim.api.nvim_get_current_tabpage() and 'TabLineSel' or 'TabLine'
    labels[#labels + 1] = ('%%#%s#%%%dT %d %s%s '):format(highlight, index, index, name:gsub('%%', '%%%%'), modified and ' +' or '')
  end
  return table.concat(labels) .. '%#TabLineFill#%T%=%999X × %X'
end

function M.select(index)
  if index > #vim.api.nvim_list_tabpages() then return end
  vim.cmd('tabnext ' .. index)
  local filetype = vim.bo.filetype
  if filetype == 'neo-tree' or filetype == 'DiffviewFiles' or filetype == 'DiffviewFileHistory' then vim.cmd('wincmd l') end
end

function M.open_workspace(directory)
  directory = vim.fn.fnamemodify(directory, ':p')
  local function git(...)
    return vim.system({ 'git', '-C', directory, ... }, { text = true }):wait()
  end
  if git('rev-parse', '--show-toplevel').code ~= 0 then return end
  local panel = vim.api.nvim_get_current_tabpage()
  vim.t[panel].workspace_title = 'Panel'
  require('neo-tree.command').execute({ action = 'show', source = 'filesystem', position = 'left', dir = directory })
  require('diffview').open({ '-C' .. directory })
  for _, base in ipairs({ 'origin/main', 'main' }) do
    if git('merge-base', base, 'HEAD').code == 0 then
      require('diffview').open({ '-C' .. directory, base .. '...HEAD', '--imply-local' })
      break
    end
  end
  vim.api.nvim_set_current_tabpage(panel)
end

-- Sessions (including :restart) save file-tree and Git views only as empty placeholders.
-- Drop those, keep the restored file windows, and rebuild the workspace as a fresh start would.
function M.restore_workspace()
  local function placeholder(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    return name:find('^diffview://') or name:find('^neo%-tree [%w_]+ %[%d+%]$') or name:find('/neo%-tree [%w_]+ %[%d+%]$')
  end
  -- A Git tab may also show real working-tree files in its diff panes; its Diffview panel identifies it.
  local function git_tab(tab)
    return vim.iter(vim.api.nvim_tabpage_list_wins(tab)):any(function(win) return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)):find('^diffview:///panels/') end)
      or vim.iter(vim.api.nvim_tabpage_list_wins(tab)):all(function(win) return placeholder(vim.api.nvim_win_get_buf(win)) end)
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if #vim.api.nvim_list_tabpages() > 1 and git_tab(tab) then vim.cmd('tabclose! ' .. vim.api.nvim_tabpage_get_number(tab)) end
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if placeholder(vim.api.nvim_win_get_buf(win)) and #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1 then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if placeholder(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end
  vim.cmd.tabfirst()
  M.open_workspace(vim.fn.getcwd())
end

return M
