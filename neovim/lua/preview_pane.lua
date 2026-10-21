-- Read-only preview pane on the right of a full-window list (folder tree, Git changes, Git history), like yazi.
-- Previews are scratch buffers, so skimming starts no language servers and leaves no buffers behind.
local M = {}

local panes = {} -- owner window -> { win, key, keep, on_enter }

function M.win(owner)
  local p = panes[owner]
  return p and vim.api.nvim_win_is_valid(p.win) and p.win or nil
end

function M.owner_of(win)
  for owner, p in pairs(panes) do
    if p.win == win then return owner end
  end
end

function M.close(owner)
  local p = panes[owner]
  panes[owner] = nil
  if p and vim.api.nvim_win_is_valid(p.win) then pcall(vim.api.nvim_win_close, p.win, true) end
end

-- Closes previews whose list is gone: it was closed, something else opened in its window, or its window closed.
local function sweep()
  for owner, p in pairs(panes) do
    if not vim.api.nvim_win_is_valid(owner) or not p.keep(owner) or not vim.api.nvim_win_is_valid(p.win) then M.close(owner) end
  end
end
local group = vim.api.nvim_create_augroup('preview-pane', { clear = true })
vim.api.nvim_create_autocmd({ 'WinClosed', 'BufWinEnter' }, { group = group, callback = function() vim.schedule(sweep) end })

local function highlight(buf, filetype)
  if not filetype then return end
  local lang = vim.treesitter.language.get_lang(filetype) or filetype
  if not pcall(vim.treesitter.start, buf, lang) then vim.bo[buf].syntax = filetype end
end

-- Shows `lines` for `key` next to `owner`. opts: title, filetype, keep(owner) -> still a list?, on_enter(owner, cursor).
function M.show(owner, key, lines, opts)
  if not vim.api.nvim_win_is_valid(owner) then return end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  highlight(buf, opts.filetype)
  vim.b[buf].preview_pane = key
  vim.keymap.set('n', 'q', function() if vim.api.nvim_win_is_valid(owner) then vim.api.nvim_set_current_win(owner) end end, { buffer = buf, desc = 'Back to the list' })
  if opts.on_enter then
    vim.keymap.set('n', '<CR>', function() opts.on_enter(owner, vim.api.nvim_win_get_cursor(0)) end, { buffer = buf, desc = 'Open this' })
  end

  local win = M.win(owner)
  if win then
    vim.api.nvim_win_set_buf(win, buf)
  else
    local width = vim.api.nvim_win_get_width(owner)
    if width < 80 then vim.api.nvim_buf_delete(buf, { force = true }); return end
    win = vim.api.nvim_open_win(buf, false, { split = 'right', win = owner, width = math.floor(width * 0.6) })
    for option, value in pairs({ number = true, relativenumber = false, wrap = false, signcolumn = 'no', cursorline = false, foldenable = false, list = false, fillchars = 'eob: ' }) do
      vim.wo[win][option] = value
    end
  end
  panes[owner] = { win = win, key = key, keep = opts.keep }
  vim.wo[win].winbar = '%#Comment# ' .. (opts.title or key):gsub('%%', '%%%%')
end

function M.key(owner)
  return M.win(owner) and panes[owner].key
end

-- Ctrl-d / Ctrl-u in the list scroll the preview by half a page.
function M.scroll(owner, key)
  local win = M.win(owner)
  if win then vim.api.nvim_win_call(win, function() vim.cmd.normal({ vim.keycode(key), bang = true }) end) end
end

-- l in the list moves into the preview; q there returns.
function M.focus(owner)
  local win = M.win(owner)
  if win then vim.api.nvim_set_current_win(win) end
end

return M
