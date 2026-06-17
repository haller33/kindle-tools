#!/usr/bin/env lua

local State = {
  path = "",
  cursor = 1,
  entries = {},
  running = true,
}

local icons_up = "[up]";
local icons_dir = "[d]";
local icons_file = "[f]";

local function get_absolute_path()
  local h = io.popen("pwd 2>/dev/null")
  if not h then return "." end
  local p = h:read("*line")
  h:close()
  return p or "."
end

local function normalize_path(path)
  if path == "" then return "/" end
  if path:sub(-1) == "/" and #path > 1 then
    path = path:sub(1, -2)
  end
  return path
end

local function list_dir(path)
  local entries = {}
  local handle = io.popen("ls -A1 " .. path .. " 2>/dev/null")
  if not handle then return entries end
  for name in handle:lines() do
    if name ~= "." and name ~= ".." then
      local full = path .. "/" .. name
      local test = io.popen("test -d " .. full .. " && echo 1 || echo 0")
      local is_dir = test:read("*line") == "1"
      test:close()
      table.insert(entries, {name = name, is_dir = is_dir})
    end
  end
  handle:close()
  table.sort(entries, function(a,b)
    if a.is_dir and not b.is_dir then return true end
    if not a.is_dir and b.is_dir then return false end
    return a.name < b.name
  end)
  if path ~= "/" then
    table.insert(entries, 1, {name = "..", is_dir = true, is_parent = true})
  end
  return entries
end

local function get_preview(path, limit)
  limit = limit or 3
  local preview = {}
  local handle = io.popen("ls -A1 " .. path .. " 2>/dev/null | head -" .. limit)
  if not handle then return preview end
  for name in handle:lines() do
    if name ~= "." and name ~= ".." then table.insert(preview, name) end
  end
  handle:close()
  return preview
end

local function cd(new_path)
  new_path = normalize_path(new_path)
  State.path = new_path
  State.entries = list_dir(new_path)
  State.cursor = 1
end

local function open_selection()
  local entry = State.entries[State.cursor]
  if not entry then return end
  local full = State.path .. "/" .. entry.name
  if entry.is_parent then
    local parent = State.path:match("(.*)/")
    if parent and parent ~= "" then cd(parent) end
  elseif entry.is_dir then
    cd(full)
  else
    os.execute("open " .. full .. " 2>/dev/null &")
    io.write("\nOpened: " .. full .. " (press Enter)")
    io.read()
  end
end

local function get_key()
  os.execute("stty -echo raw 2>/dev/null")
  local key = io.read(1)
  os.execute("stty echo -raw 2>/dev/null")
  return key
end

local function get_size()
  local h = io.popen("stty size 2>/dev/null")
  if h then
    local rows, cols = h:read("*line"):match("(%d+)%s+(%d+)")
    h:close()
    if rows and cols then return tonumber(rows), tonumber(cols) end
  end
  return 24, 80
end

local function render()
  local rows, cols = get_size()
  local selected = State.entries[State.cursor]

  -- Ensure path is set
  if not State.path or State.path == "" then
    State.path = get_absolute_path()
  end

  -- Build previews
  local selected_preview = ""
  if selected and selected.is_dir and not selected.is_parent then
    local preview_path = State.path .. "/" .. selected.name
    local items = get_preview(preview_path, 3)
    local str = table.concat(items, ", ")
    if #items == 0 then str = "(empty)"
    elseif #items == 3 then str = str .. ", ..." end
    selected_preview = " > " .. str
  end

  local parent_path = State.path:match("(.*)/")
  local parent_preview = ""
  if parent_path and parent_path ~= "" then
    local items = get_preview(parent_path, 3)
    local str = table.concat(items, ", ")
    if #items == 0 then str = "(empty)"
    elseif #items == 3 then str = str .. ", ..." end
    parent_preview = " ^ " .. str
  end

  -- Header lines: path + up to two previews + blank separator
  local header_lines = 1
  if selected_preview ~= "" then header_lines = header_lines + 1 end
  if parent_preview ~= "" then header_lines = header_lines + 1 end
  header_lines = header_lines + 1  -- blank line
  local status_line = 1
  local max_list = rows - header_lines - status_line

  io.write("\27[2J\27[H")  -- clear screen, home

  -- io.write("\n")  -- blank separator
  -- Path at the very top
  io.write(State.path .. "\n")
  -- io.write("Path: " .. State.path .. "\n")

  -- Previews
  if selected_preview ~= "" then io.write(selected_preview .. "\n") end
  if parent_preview ~= "" then io.write(parent_preview .. "\n") end
  io.write("\n")  -- blank separator

  -- File list
  local entries = State.entries
  local total = #entries
  local start = math.max(1, State.cursor - math.floor(max_list/2))
  local finish = math.min(total, start + max_list - 1)
  if finish - start < max_list - 1 and start > 1 then
    start = math.max(1, total - max_list + 1)
    finish = total
  end

  for i = start, finish do
    local e = entries[i]
    local mark = (i == State.cursor) and ">" or " "
    local icon = e.is_dir and (e.is_parent and icons_up or icons_dir) or icons_file
    local name = e.name
    if #name > cols - 10 then name = name:sub(1, cols-13).."..." end
    io.write(string.format("%s %s %s\n", mark, icon, name))
  end

  -- Fill remaining lines with blanks to overwrite old content
  local used = header_lines + (finish - start + 1)
  for i = used, rows - 3 do
    io.write("\n")
  end

  -- Status bar at bottom
  io.write(string.format(" %d/%d  j/k  l/open  h/up  q\n", State.cursor, total))
end

local function main()
  State.path = get_absolute_path()
  State.entries = list_dir(State.path)
  while State.running do
    render()
    local key = get_key()
    if key == "q" then
      State.running = false
    elseif key == "j" or key == "\n" then
      if State.cursor < #State.entries then State.cursor = State.cursor + 1 end
    elseif key == "k" then
      if State.cursor > 1 then State.cursor = State.cursor - 1 end
    elseif key == "l" or key == " " then
      open_selection()
    elseif key == "h" or key == "\27" then
      local parent = State.path:match("(.*)/")
      if parent and parent ~= "" then cd(parent) end
    end
  end
end

local function cleanup()
  os.execute("stty echo -raw 2>/dev/null")
  io.write("\27[?25h\27[J")
  io.write("\nGoodbye!\n")
end

pcall(main)
cleanup()
