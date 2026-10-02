local M = {}
local current = 1
local title_click = false

function M.toggle()
  require('toggleterm.terminal').Terminal:new({ count = current }):toggle()
end

function M.on_open(term)
  current = term.id
  for _, key in ipairs({ '<Esc><Esc>', [[<C-\><C-n>]] }) do
    vim.keymap.set('t', key, function() term:close() end, { buffer = term.bufnr, desc = 'Hide floating terminal' })
  end
  vim.keymap.set({ 'n', 't' }, '<LeftRelease>', function()
    if title_click then
      title_click = false
      return ''
    end
    return '<LeftRelease>'
  end, { buffer = term.bufnr, expr = true, desc = 'Finish terminal slot click' })
  local labels = {}
  for index = 1, 9 do
    labels[index] = index == current and ('[' .. index .. ']') or tostring(index)
  end
  term.display_name = ' ' .. table.concat(labels, '  ') .. ' '
  vim.api.nvim_win_set_config(term.window, { title = term.display_name, title_pos = 'center' })
  vim.cmd.startinsert()
end

function M.click_title(term, mouse)
  local position = vim.api.nvim_win_get_position(term.window)
  if mouse.screenrow ~= position[1] + 1 then return false end
  local width = vim.api.nvim_win_get_width(term.window)
  local column = mouse.screencol - position[2] - 1 - math.floor((width - #term.display_name) / 2)
  if column < 1 or column > #term.display_name then return false end
  local index = tonumber(term.display_name:sub(column, column))
  if not index then return false end
  title_click = true
  if index ~= term.id then
    vim.schedule(function()
      term:close()
      require('toggleterm.terminal').Terminal:new({ count = index }):open()
    end)
  end
  return true
end

return M
