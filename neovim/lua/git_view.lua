-- Git lists in the one editing view, like the folder tree: Space gg current changes, Space gm changes against main,
-- Space gb against the branch this one was created from (else a picked one), Space gh commit history, Space gf history of the current file.
-- In the change lists j/k previews the change under the cursor read-only on the right; the history lists are a
-- full-width commit graph without preview. Enter opens the side-by-side diff in place (Diffview without its file panel); q goes back.
local M = {}
local pane = require('preview_pane')
local ns = vim.api.nvim_create_namespace('git-view')
local timer = vim.uv.new_timer()
local empty_tree = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
local max_preview_lines = 20000

M.preview_enabled = true
M.all_branches = true -- Space gh shows every local and remote branch; a toggles to the current branch only.
local lists = {} -- list buffer -> { spec, items (line -> item), back (buffer) }

local function git(root, args)
  local result = vim.system(vim.list_extend({ 'git', '-C', root }, args), { text = true }):wait()
  return result.code == 0 and result.stdout or nil, result
end

-- The repository of the file being edited, else of the working directory.
local function repository()
  local list = lists[vim.api.nvim_get_current_buf()]
  if list then return list.spec.root end
  local file = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  local dir = file ~= '' and vim.fs.dirname(file) or vim.fn.getcwd()
  local out = git(dir, { 'rev-parse', '--show-toplevel' })
  if not out then vim.notify('Not inside a Git repository', vim.log.levels.WARN) end
  return out and vim.trim(out)
end

-- A change list's groups of files: Space gg splits staged from unstaged changes, the other lists are one group
-- between `base` and `target` (a commit, or the working tree when nil).
local function sections_of(spec)
  return spec.sections or { { revs = { spec.base, spec.target }, diff = spec.diff, untracked = spec.untracked } }
end

-- Changed files of one section, with line counts.
local function changed_files(root, section)
  local revs = section.revs
  local status = git(root, vim.list_extend({ 'diff', '-M', '-z', '--name-status' }, revs)) or ''
  local counts = git(root, vim.list_extend({ 'diff', '-M', '-z', '--numstat' }, revs)) or ''
  local files, by_path = {}, {}
  local tokens = vim.split(status, '\0', { trimempty = true })
  local i = 1
  while i <= #tokens do
    local letter = tokens[i]:sub(1, 1)
    local file = { status = letter }
    if letter == 'R' or letter == 'C' then
      file.old, file.path, i = tokens[i + 1], tokens[i + 2], i + 3
    else
      file.path, i = tokens[i + 1], i + 2
    end
    files[#files + 1], by_path[file.path] = file, file
  end
  tokens = vim.split(counts, '\0', { trimempty = true })
  i = 1
  while i <= #tokens do
    local added, removed, path = tokens[i]:match('^(%S+)\t(%S+)\t(.*)$')
    if path == '' then path, i = tokens[i + 2], i + 3 else i = i + 1 end
    local file = by_path[path or '']
    if file then file.added, file.removed = tonumber(added), tonumber(removed) end
  end
  if section.untracked then
    for _, path in ipairs(vim.split(git(root, { 'ls-files', '--others', '--exclude-standard', '-z' }) or '', '\0', { trimempty = true })) do
      if not by_path[path] then files[#files + 1] = { status = '?', path = path, untracked = true } end
    end
  end
  return files
end

local status_hl = { A = 'Added', ['?'] = 'Added', M = 'Changed', R = 'Changed', C = 'Changed', T = 'Changed', D = 'Removed', U = 'DiagnosticError' }

-- Renders `files` of `section` as a tree with single-child folders joined (src/app/models/), folders first.
local function render_files(section, files, lines, marks, items)
  local tree = { dirs = {}, files = {} }
  for _, file in ipairs(files) do
    local node, parts = tree, vim.split(file.path, '/')
    for depth = 1, #parts - 1 do
      local path = table.concat(parts, '/', 1, depth)
      node.dirs[parts[depth]] = node.dirs[parts[depth]] or { name = parts[depth], path = path, dirs = {}, files = {} }
      node = node.dirs[parts[depth]]
    end
    node.files[#node.files + 1] = file
  end
  local devicons_ok, devicons = pcall(require, 'nvim-web-devicons')
  local function mark(col, end_col, hl) marks[#marks + 1] = { #lines, col, end_col, hl } end
  local function walk(node, indent)
    local names = vim.tbl_keys(node.dirs)
    table.sort(names)
    for _, name in ipairs(names) do
      local dir = node.dirs[name]
      local label = dir.name
      while #dir.files == 0 and vim.tbl_count(dir.dirs) == 1 do
        local _, only = next(dir.dirs)
        label, dir = label .. '/' .. only.name, only
      end
      local prefix = indent .. '  ' .. ' '
      lines[#lines + 1] = prefix .. label .. '/'
      mark(#indent + 2, #prefix, 'Directory')
      mark(#prefix, #lines[#lines], 'Directory')
      items[#lines] = { kind = 'dir', path = dir.path, section = section }
      walk(dir, indent .. '  ')
    end
    table.sort(node.files, function(a, b) return a.path < b.path end)
    for _, file in ipairs(node.files) do
      local name = vim.fs.basename(file.path)
      local icon, icon_hl = '', 'Normal'
      if devicons_ok then icon, icon_hl = devicons.get_icon(name, name:match('%.([^.]+)$'), { default = true }) end
      local prefix = indent .. file.status .. ' '
      local line = prefix .. icon .. ' ' .. name
      lines[#lines + 1] = line
      mark(#indent, #indent + 1, status_hl[file.status] or 'Changed')
      mark(#prefix, #prefix + #icon, icon_hl)
      if file.old then
        local renamed = '  ← ' .. file.old
        mark(#line, #line + #renamed, 'Comment')
        line = line .. renamed
      end
      if file.added then
        local added, removed = '  +' .. file.added, ' -' .. file.removed
        mark(#line, #line + #added, 'Added')
        mark(#line + #added, #line + #added + #removed, 'Removed')
        line = line .. added .. removed
      end
      lines[#lines] = line
      items[#lines] = { kind = 'file', file = file, section = section }
    end
  end
  walk(tree, '')
end

-- What the cursor is on, kept across refreshes: the same file in the same section, else the same file.
local function item_path(item) return item.file and item.file.path or item.path or item.sha or ('\0' .. item.kind) end
local function item_focus(item) return { section = item.section and item.section.name, path = item_path(item) } end

-- Git's graph colors (per branch, kept along its line) mapped to highlight groups; the commit dots stay uncolored.
local graph_colors = { DiagnosticError = { 31 }, DiagnosticOk = { 32 }, DiagnosticWarn = { 33 }, DiagnosticInfo = { 34 }, Function = { 35 }, DiagnosticHint = { 36 } }
local graph_hl = {}
for group, codes in pairs(graph_colors) do
  for _, code in ipairs(codes) do graph_hl[tostring(code)], graph_hl['1;' .. code] = group, group end
end
local graph_chars = { ['*'] = '●', ['|'] = '│', ['/'] = '╱', ['\\'] = '╲', ['-'] = '─', ['_'] = '_' }

-- Converts git's colored ASCII graph into box-drawing characters with highlights starting at byte `col`.
local function graph(text, row, col, marks)
  local out, group = {}, nil
  local i = 1
  while i <= #text do
    local code, stop = text:match('^\27%[([%d;]*)m()', i)
    if code then
      group = graph_hl[code]
      i = stop
    else
      local char = text:sub(i, i)
      local shown = graph_chars[char] or char
      if group and char ~= ' ' then marks[#marks + 1] = { row, col, col + #shown, group } end
      out[#out + 1] = shown
      col = col + #shown
      i = i + 1
    end
  end
  return (table.concat(out):gsub('%s+$', ''))
end

local function render_log(spec, lines, marks, items)
  local args = { 'log', '--color=always', '--format=%x1e%H%x1f%h%x1f%ad%x1f%an%x1f%s%x1f%D', '--date=short', '-n', '2000' }
  if spec.path then -- One file's history is one line of commits; git's graph would only add "..." rows.
    vim.list_extend(args, { '--follow', '--', spec.path })
  else
    args[#args + 1] = '--graph'
    if spec.all then vim.list_extend(args, { '--branches', '--remotes', 'HEAD' }) end
  end
  local out = git(spec.root, args) or ''
  local count = 0
  local blank = (' '):rep(8 + 2 + 10 + 2 + 16 + 2)
  for record in out:gmatch('[^\n]+') do
    local row = #lines + 1
    local graph_text, fields = record:match('^(.-)\30(.*)$')
    if not fields then -- A line of the graph between commits.
      lines[row] = blank .. graph(record, row, #blank, marks)
    else
      local full, short, date, author, subject, refs = unpack(vim.split(fields, '\31'))
      author = vim.fn.strcharpart(author, 0, 16)
      local line = ('%s  %s  %s%s  '):format(short, date, author, (' '):rep(16 - vim.fn.strchars(author)))
      marks[#marks + 1] = { row, 0, #short, 'Identifier' }
      marks[#marks + 1] = { row, #short + 2, #short + 12, 'Comment' }
      marks[#marks + 1] = { row, #short + 14, #line, 'Special' }
      line = line .. graph(spec.path and '*' or graph_text, row, #line, marks) .. ' '
      if refs ~= '' then
        local decoration = '(' .. refs:gsub('HEAD %-> ', ''):gsub('tag: ', '') .. ') '
        marks[#marks + 1] = { row, #line, #line + #decoration - 1, 'Constant' }
        line = line .. decoration
      end
      lines[row] = line .. subject
      items[row] = { kind = 'commit', sha = full, short = short, head = refs:find('HEAD') ~= nil }
      count = count + 1
    end
  end
  if count == 0 then lines[#lines + 1] = '  No commits' ; marks[#marks + 1] = { #lines, 0, #lines[#lines], 'Comment' } end
  return count
end

local function render(buf, focus)
  local list = lists[buf]
  local spec = list.spec
  local lines, marks, items = { '' }, {}, { { kind = 'header' } }
  local summary
  if spec.kind == 'log' then
    local count = render_log(spec, lines, marks, items)
    summary = (count == 2000 and 'latest ' or '') .. count .. (count == 1 and ' commit' or ' commits')
    if not spec.path then summary = summary .. '  ·  a: ' .. (spec.all and 'current branch only' or 'all branches') end
  else
    local function count(files, added, removed)
      for _, file in ipairs(files) do added, removed = added + (file.added or 0), removed + (file.removed or 0) end
      return added, removed
    end
    local paths, added, removed = {}, 0, 0
    for _, section in ipairs(sections_of(spec)) do
      local files = changed_files(spec.root, section)
      for _, file in ipairs(files) do paths[file.path] = true end
      added, removed = count(files, added, removed)
      if section.title and #files > 0 then
        local section_added, section_removed = count(files, 0, 0)
        lines[#lines + 1] = ' ' .. section.title .. '  ·  ' .. #files .. (#files == 1 and ' file' or ' files') .. '  +' .. section_added .. ' -' .. section_removed
        marks[#marks + 1] = { #lines, 1, #section.title + 1, 'Statement' }
        marks[#marks + 1] = { #lines, #section.title + 1, #lines[#lines], 'Comment' }
        items[#lines] = { kind = 'section', section = section }
      end
      render_files(section, files, lines, marks, items)
    end
    local total = vim.tbl_count(paths)
    if total == 0 then lines[#lines + 1] = '  No changes'; marks[#marks + 1] = { #lines, 0, #lines[#lines], 'Comment' } end
    summary = total .. (total == 1 and ' file' or ' files') .. '  +' .. added .. ' -' .. removed
  end
  lines[1] = ' ' .. spec.title .. '  ·  ' .. summary
  marks[#marks + 1] = { 1, 1, #spec.title + 1, 'Title' }
  marks[#marks + 1] = { 1, #spec.title + 1, #lines[1], 'Comment' }

  local win = vim.fn.bufwinid(buf)
  local previous = win ~= -1 and list.items[vim.api.nvim_win_get_cursor(win)[1]]
  focus = focus or (previous and item_focus(previous))
  list.items = items
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, m[1] - 1, m[2], { end_col = m[3], hl_group = m[4] })
  end
  if win ~= -1 then
    local row, row_same_path, row_default
    for line = 2, #lines do
      local item = items[line]
      if item and focus and item_path(item) == focus.path then
        if (item.section and item.section.name) == focus.section then row = line; break end
        row_same_path = row_same_path or line -- Staged or unstaged since: the file in its other section.
      end
      if item and item.head then row_default = line end -- The history starts on the checked-out commit.
      if item and not row_default and (item.kind == 'file' or item.kind == 'commit') then row_default = line end
    end
    row = row or row_same_path or row_default or math.min(#lines, 2)
    vim.api.nvim_win_set_cursor(win, { row, 0 })
  end
end

-- Preview of the item under the cursor, produced by Git asynchronously.
local function preview_command(spec, item)
  if spec.kind == 'log' then
    if item.kind ~= 'commit' then return nil end
    local args = { 'show', '--stat', '--patch', '--format=fuller', item.sha }
    if spec.path then vim.list_extend(args, { '--', spec.path }) end
    return args, 'git', item.short
  end
  if item.kind == 'header' then return vim.list_extend({ 'diff', '-M', '--stat' }, { spec.base, spec.target }), 'git', spec.title end
  local revs = item.section.revs
  if item.kind == 'section' then return vim.list_extend({ 'diff', '-M', '--stat' }, revs), 'git', item.section.title end
  if item.kind == 'dir' then return vim.list_extend(vim.list_extend({ 'diff', '-M' }, revs), { '--', item.path }), 'diff', item.path .. '/' end
  local file = item.file
  if file.untracked then return { 'diff', '--no-index', '--', '/dev/null', file.path }, 'diff', file.path, true end
  local args = vim.list_extend(vim.list_extend({ 'diff', '-M' }, revs), { '--' })
  if file.old then args[#args + 1] = file.old end
  args[#args + 1] = file.path
  return args, 'diff', file.path, true
end

local function item_key(buf, item)
  return lists[buf].spec.name .. ':' .. (item.section and item.section.name or '') .. ':' .. item_path(item)
end

local function update(win, force)
  if not M.preview_enabled or not vim.api.nvim_win_is_valid(win) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  local list = lists[buf]
  if not list then return end
  if list.spec.kind == 'log' then return pane.close(win) end
  local item = list.items[vim.api.nvim_win_get_cursor(win)[1]]
  if not item then return end
  local key = item_key(buf, item)
  if not force and pane.key(win) == key then return end
  local args, filetype, title, single_file = preview_command(list.spec, item)
  if not args then return end
  list.pending = key
  vim.system(vim.list_extend({ 'git', '-C', list.spec.root, '--no-pager', '-c', 'color.ui=never' }, args), { text = true }, vim.schedule_wrap(function(result)
    if list.pending ~= key or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then return end
    list.pending = nil
    local out = result.stdout ~= '' and result.stdout or result.stderr
    local lines = vim.split(out, '\n', { trimempty = false })
    if lines[#lines] == '' then lines[#lines] = nil end
    if single_file then -- The title already names the file: start at the first change.
      for index, line in ipairs(lines) do
        if line:match('^@@') then lines = vim.list_slice(lines, index); break end
      end
    end
    if #lines == 0 then lines = { '(no textual changes)' } end
    if #lines > max_preview_lines then
      lines = vim.list_slice(lines, 1, max_preview_lines)
      lines[#lines + 1] = ('… (preview stops after %d lines)'):format(max_preview_lines)
    end
    pane.show(win, key, lines, {
      title = title,
      filetype = filetype,
      keep = function(owner) return lists[vim.api.nvim_win_get_buf(owner)] ~= nil end,
      on_enter = function(owner) vim.api.nvim_set_current_win(owner); M.select() end,
    })
  end))
end

local diff_origin -- Tab page the side-by-side diff was opened from.

-- Opens the side-by-side diff in place of the list; q returns to the list.
local function open_diff(root, revs, path)
  local args = { '-C' .. root }
  vim.list_extend(args, revs)
  if path then args[#args + 1] = '--selected-file=' .. vim.fs.joinpath(root, path) end
  diff_origin = vim.api.nvim_get_current_tabpage()
  require('diffview').open(args)
end

-- The first file in `section` (any section when nil) under the folder `path` (anywhere when nil).
local function first_file(list, section, path)
  for line = 1, vim.api.nvim_buf_line_count(0) do
    local item = list.items[line]
    if item and item.kind == 'file' and (not section or item.section == section) and (not path or vim.startswith(item.file.path, path .. '/')) then return item end
  end
end

local show

-- Enter: the diff of the file under the cursor; on a commit, its changed files (or its diff, in a file's history).
function M.select()
  local buf = vim.api.nvim_get_current_buf()
  local list = lists[buf]
  if not list then return end
  local spec = list.spec
  local item = list.items[vim.fn.line('.')]
  if not item then return end
  if spec.kind == 'log' then
    if item.kind ~= 'commit' then return end
    local parent = git(spec.root, { 'rev-parse', '--verify', '--quiet', item.sha .. '^1' })
    parent = parent and vim.trim(parent) or empty_tree
    if spec.path then return open_diff(spec.root, { parent .. '..' .. item.sha }, spec.path) end
    local subject = vim.trim(git(spec.root, { 'log', '-1', '--format=%s', item.sha }) or '')
    return show({
      kind = 'files', name = 'commit/' .. item.sha, root = spec.root, title = item.short .. ' ' .. subject,
      base = parent, target = item.sha, diff = { parent .. '..' .. item.sha },
    })
  end
  local file = item.kind == 'file' and item or first_file(list, item.section, item.kind == 'dir' and item.path or nil)
  if file then open_diff(spec.root, file.section.diff, file.file.path) end
end

-- q: back to what the window showed before the Git lists, or to the folder tree.
function M.back()
  local list = lists[vim.api.nvim_get_current_buf()]
  local back = list and list.back
  if back and vim.api.nvim_buf_is_valid(back) and vim.bo[back].filetype ~= 'neo-tree' then
    vim.api.nvim_win_set_buf(0, back)
  else
    require('neo-tree.command').execute({ source = 'filesystem', position = 'current', dir = list and list.spec.root or vim.fn.getcwd() })
  end
end

-- In the history graph the cursor only stops on commits: rows that only draw branch lines are stepped over.
local function skip_graph_rows(buf)
  local list = lists[buf]
  local row = vim.fn.line('.')
  local last = list.row or row
  list.row = row
  if row == 1 or list.items[row] then return end
  local step = row < last and -1 or 1
  local count = vim.api.nvim_buf_line_count(buf)
  for target = row + step, step > 0 and count or 2, step do
    if list.items[target] then list.row = target; return vim.api.nvim_win_set_cursor(0, { target, 0 }) end
  end
  for target = row - step, step > 0 and 2 or count, -step do
    if list.items[target] then list.row = target; return vim.api.nvim_win_set_cursor(0, { target, 0 }) end
  end
end

local function setup_buffer(buf, kind)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, nowait = true, desc = desc }) end
  map('<CR>', M.select, kind == 'log' and 'Open the commit' or 'Open the diff')
  map('o', M.select, kind == 'log' and 'Open the commit' or 'Open the diff')
  map('q', M.back, 'Back')
  map('R', function() render(buf); update(vim.api.nvim_get_current_win(), true) end, 'Refresh')
  if kind == 'log' then
    map('a', function()
      local spec = lists[buf].spec
      if spec.path then return end
      M.all_branches = not M.all_branches
      lists[buf].spec = M.history_spec(spec.root)
      render(buf)
    end, 'Toggle all branches / current branch')
  else
    map('P', function()
      M.preview_enabled = not M.preview_enabled
      if M.preview_enabled then update(vim.api.nvim_get_current_win(), true) else pane.close(vim.api.nvim_get_current_win()) end
    end, 'Toggle preview')
    map('l', function() pane.focus(vim.api.nvim_get_current_win()) end, 'Move into the preview')
    for lhs, key in pairs({ ['<C-d>'] = '<C-d>', ['<C-u>'] = '<C-u>', ['<C-f>'] = '<C-d>', ['<C-b>'] = '<C-u>' }) do
      map(lhs, function() pane.scroll(vim.api.nvim_get_current_win(), key) end, 'Scroll the preview')
    end
  end
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      if kind == 'log' then return skip_graph_rows(buf) end
      local win = vim.api.nvim_get_current_win()
      timer:stop()
      timer:start(30, 0, vim.schedule_wrap(function() update(win) end))
    end,
  })
  -- Coming back from a diff or a file: the changes may have moved on.
  vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained' }, {
    buffer = buf,
    callback = function()
      if not lists[buf] or vim.api.nvim_get_current_buf() ~= buf then return end
      render(buf)
      update(vim.api.nvim_get_current_win(), true)
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, callback = function() lists[buf] = nil end })
end

-- Shows the list described by `spec` in the editing window; the same key in that list goes back.
show = function(spec)
  local in_diff = vim.t.diffview_title ~= nil
  local win = require('search').selection_window()
  if win ~= 0 then vim.api.nvim_set_current_win(win) end
  win = vim.api.nvim_get_current_win()
  local current = vim.api.nvim_get_current_buf()
  local current_list = lists[current]
  if current_list and current_list.spec.name == spec.name then
    if not in_diff and spec.top then return M.back() end
    current_list.spec = spec
    render(current)
    return update(win, true)
  end

  local name = 'gitview://' .. spec.name
  local buf = vim.fn.bufnr('^' .. vim.pesc(name) .. '$')
  if buf == -1 or not lists[buf] then
    if buf ~= -1 then vim.api.nvim_buf_delete(buf, { force = true }) end
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].bufhidden = spec.top and 'hide' or 'wipe'
    vim.b[buf].git_view = true
    lists[buf] = { items = {} }
    setup_buffer(buf, spec.kind)
  end
  local list = lists[buf]
  list.spec = spec
  -- Switching between the top-level lists keeps going back to the file; a commit's files go back to the history.
  list.back = current_list and spec.top and current_list.spec.top and current_list.back or current
  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].filetype = 'gitview'
  for option, value in pairs({ number = false, relativenumber = false, cursorline = true, wrap = false, signcolumn = 'no', foldenable = false, list = false, spell = false, fillchars = 'eob: ' }) do
    vim.api.nvim_set_option_value(option, value, { scope = 'local', win = win })
  end
  render(buf)
  update(win, true)
end

function M.changes()
  local root = repository()
  if not root then return end
  show({
    kind = 'files', top = true, name = 'changes', root = root, title = 'Current changes', base = 'HEAD',
    -- Diffview with --cached shows only the staged side; without it the unstaged entry of a file comes first.
    sections = {
      { name = 'staged', title = 'Staged', revs = { '--cached' }, diff = { '--cached' } },
      { name = 'unstaged', title = 'Unstaged', revs = {}, diff = {}, untracked = true },
    },
  })
end

-- The branch the current one was created from. Git doesn't store it, so: the branch's reflog ("Created from X", or the
-- "checkout: moving from X" that created it) unless it was rebased since; otherwise the branch it forked from last,
-- i.e. the one sharing the most of HEAD's history (fewest HEAD commits it lacks, then fewest of its own on top).
function M.parent_branch(root)
  local branch = vim.trim(git(root, { 'branch', '--show-current' }) or '')
  if branch == '' then return nil end
  local own = { [branch] = true, ['origin/' .. branch] = true }
  local upstream = git(root, { 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}' })
  if upstream then own[vim.trim(upstream)] = true end
  -- Branches HEAD has commits beyond (those containing HEAD would compare empty): name -> { ahead, behind }.
  local refs = git(root, { 'for-each-ref', '--format=%(refname:short)%09%(symref)%09%(ahead-behind:HEAD)', 'refs/heads', 'refs/remotes' }) or ''
  local candidates, best = {}, nil
  for name, symref, ahead, behind in refs:gmatch('([^\t\n]+)\t([^\t\n]*)\t(%d+) (%d+)') do
    ahead, behind = tonumber(ahead), tonumber(behind)
    if symref == '' and not own[name] and behind > 0 then
      candidates[name] = true
      if not best or behind < best.behind or (behind == best.behind and ahead < best.ahead) then
        best = { name = name, ahead = ahead, behind = behind }
      end
    end
  end
  local reflog = git(root, { 'reflog', 'show', '--format=%gs', 'refs/heads/' .. branch, '--' }) or ''
  if not reflog:find('(finish): refs/heads/', 1, true) then -- rebase or pull --rebase
    local created = reflog:match('branch: Created from ([^\n]+)\n?$')
    if created == 'HEAD' then
      local moves = git(root, { 'reflog', 'show', '--format=%gs', 'HEAD', '--' }) or ''
      for from in moves:gmatch('checkout: moving from ([^\n]+) to ' .. vim.pesc(branch) .. '\n') do created = from end
    end
    if created and candidates[created] then return created end
  end
  return best and best.name
end

-- Changes on this branch since it left `base` (main by default), including uncommitted ones.
function M.against(base)
  local root = repository()
  if not root then return end
  if not base then
    for _, candidate in ipairs({ 'origin/main', 'main', 'origin/master', 'master' }) do
      if git(root, { 'rev-parse', '--verify', '--quiet', candidate }) then base = candidate; break end
    end
    if not base then return vim.notify('No main branch found', vim.log.levels.WARN) end
  end
  local merge_base = git(root, { 'merge-base', base, 'HEAD' })
  if not merge_base then return vim.notify('No common history with ' .. base, vim.log.levels.WARN) end
  show({
    kind = 'files', top = true, name = 'against', root = root, title = 'Changes against ' .. base:gsub('^origin/', ''),
    base = vim.trim(merge_base), diff = { base .. '...HEAD', '--imply-local' },
  })
end

-- Changes since leaving the branch this one was created from; without one, pick a branch.
function M.against_parent()
  local root = repository()
  if not root then return end
  local parent = M.parent_branch(root)
  if parent then return M.against(parent) end
  vim.notify('No parent branch found; pick one to compare against')
  require('diff_base').pick()
end

function M.history_spec(root)
  local branch = vim.trim(git(root, { 'branch', '--show-current' }) or '')
  local title = M.all_branches and 'History of all branches' or ('History' .. (branch ~= '' and (' of ' .. branch) or ''))
  return { kind = 'log', top = true, name = 'history', root = root, title = title, all = M.all_branches }
end

function M.history()
  local root = repository()
  if root then show(M.history_spec(root)) end
end

function M.file_history()
  local file = vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) or ''
  if file == '' then return vim.notify('Open a file to see its history', vim.log.levels.WARN) end
  local root = repository()
  if not root then return end
  local path = vim.fs.relpath(vim.uv.fs_realpath(root) or root, vim.uv.fs_realpath(file) or file) or file
  show({ kind = 'log', top = true, name = 'file-history', root = root, title = 'History of ' .. path, path = path })
end

function M.root() return repository() end

-- Diffview hooks: the diff fills the view, no file panel; the cursor starts in the editable right side.
function M.view_opened(view)
  if view.panel and view.panel:is_open() then view.panel:close() end
  local right = view.cur_layout and view.cur_layout.b
  if right and right.id and vim.api.nvim_win_is_valid(right.id) then vim.api.nvim_set_current_win(right.id) end
  vim.cmd('horizontal wincmd =')
end

-- q in the diff: back to the list, on the file the diff ended on.
function M.close_diff()
  local view = require('diffview.lib').get_current_view()
  if not view then return end
  local entry = view.cur_entry
  local origin = diff_origin
  view:close()
  require('diffview.lib').dispose_view(view)
  if origin and vim.api.nvim_tabpage_is_valid(origin) then vim.api.nvim_set_current_tabpage(origin) end
  local buf = vim.api.nvim_get_current_buf()
  if lists[buf] then
    -- A staged file is a working entry of a --cached diff (right side the index), or a staged entry of the full one.
    local staged = entry and (entry.kind == 'staged' or view.right.type == require('diffview.vcs.rev').RevType.STAGE)
    render(buf, entry and { section = lists[buf].spec.sections and (staged and 'staged' or 'unstaged'), path = entry.path })
    update(vim.api.nvim_get_current_win(), true)
  end
end

return M
