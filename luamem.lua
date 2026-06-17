#!/usr/bin/env lua

-- memory_usage.lua - List memory usage of all processes on Linux
-- Usage:
--   memory_usage.lua [--sort | -s]   (sort flat list by RSS descending)
--   memory_usage.lua [--tree | -t]   (show process tree)
--   memory_usage.lua [--help | -h]   (show this help)

-- Localize functions for speed
local match, open, insert, tonumber, print = string.match, io.open, table.insert, tonumber, print
local sort, format, rep = table.sort, string.format, string.rep
local tostring = tostring  -- used only for error messages

-- Parse command line arguments
local sort_by_rss, tree_mode = false, false
if arg and #arg > 0 then
    local opt = arg[1]
    if opt == "--help" or opt == "-h" then
        print("Usage: memory_usage.lua [OPTION]")
        print("Options:")
        print("  --sort, -s    Sort processes by memory usage (RSS) descending")
        print("  --tree, -t    Show process tree (hierarchical view)")
        print("  --help, -h    Show this help message")
        print("\nWithout options, sorts by PID ascending.")
        os.exit(0)
    elseif opt == "--sort" or opt == "-s" then
        sort_by_rss = true
    elseif opt == "--tree" or opt == "-t" then
        tree_mode = true
    else
        print("Unknown option: " .. tostring(opt))
        print("Use --help for usage.")
        os.exit(1)
    end
end

-- Get list of numeric PIDs from /proc
local function get_pid_list()
    local pids = {}
    local handle = io.popen("ls -d /proc/[0-9]* 2>/dev/null")
    if not handle then return pids end
    for dir in handle:lines() do
        local pid_str = match(dir, "/proc/(%d+)")
        if pid_str then insert(pids, tonumber(pid_str)) end
    end
    handle:close()
    return pids
end

-- Read /proc/[pid]/status and extract Name, VmRSS, PPid
local function get_process_info(pid)
    local file = open("/proc/" .. pid .. "/status", "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()

    local name = match(content, "^Name:[%s]*(.-)[\n\r]") or "unknown"
    local rss_str = match(content, "VmRSS:[%s]*(%d+)")
    local ppid_str = match(content, "PPid:[%s]*(%d+)")

    return {
        pid = pid,
        name = name,
        rss_kb = rss_str and tonumber(rss_str) or 0,
        ppid = ppid_str and tonumber(ppid_str) or 0
    }
end

-- Collect data for all PIDs into a map (pid -> info)
local by_pid = {}
for _, pid in ipairs(get_pid_list()) do
    local info = get_process_info(pid)
    if info then by_pid[pid] = info end
end

-- ------------------------------------------------------------------------
-- Flat list mode
-- ------------------------------------------------------------------------
local function print_flat()
    -- Convert map to array
    local processes = {}
    for _, info in pairs(by_pid) do insert(processes, info) end

    -- Sort
    if sort_by_rss then
        sort(processes, function(a, b)
            if a.rss_kb ~= b.rss_kb then return a.rss_kb > b.rss_kb end
            return a.pid < b.pid
        end)
    else
        sort(processes, function(a, b) return a.pid < b.pid end)
    end

    -- Print table
    print(format("%-8s %-20s %12s %10s", "PID", "NAME", "RSS (kB)", "RSS (MB)"))
    print(rep("-", 54))
    local total_kb = 0
    for _, p in ipairs(processes) do
        print(format("%-8d %-20s %12d %10.2f", p.pid, p.name, p.rss_kb, p.rss_kb / 1024))
        total_kb = total_kb + p.rss_kb
    end
    print(rep("-", 54))
    print(format("%-30s %12d %10.2f", "Total", total_kb, total_kb / 1024))
end

-- ------------------------------------------------------------------------
-- Tree mode
-- ------------------------------------------------------------------------
local function print_tree()
    -- Build parent -> children map
    local children = {}
    for pid, info in pairs(by_pid) do
        local ppid = info.ppid
        children[ppid] = children[ppid] or {}
        insert(children[ppid], pid)
    end
    -- Sort children for consistent output
    for _, list in pairs(children) do sort(list) end

    local printed = {}   -- track printed PIDs

    -- Recursive printing
    local function print_node(pid, indent, is_last)
        local info = by_pid[pid]
        if not info then return end
        printed[pid] = true

        local prefix = indent .. (is_last == nil and "" or (is_last and "└─ " or "├─ "))
        print(prefix .. format("%-8d %-20s %12d %10.2f",
                info.pid, info.name, info.rss_kb, info.rss_kb / 1024))

        local child_indent = indent .. (is_last == nil and "" or (is_last and "   " or "│  "))
        local child_list = children[pid]
        if child_list then
            for i, child_pid in ipairs(child_list) do
                print_node(child_pid, child_indent, i == #child_list)
            end
        end
    end

    -- Header
    print(format("%-8s %-20s %12s %10s", "PID", "NAME", "RSS (kB)", "RSS (MB)"))
    print(rep("-", 54))

    -- Start from PID 1 (init)
    if by_pid[1] then
        print_node(1, "", nil)   -- nil means no tree symbol at the root
    else
        print("(PID 1 not found)")
    end

    -- Print orphans (processes not reachable from PID 1)
    local orphans = {}
    for pid, _ in pairs(by_pid) do
        if not printed[pid] then insert(orphans, pid) end
    end
    sort(orphans)
    if #orphans > 0 then
        print("\n-- Processes not reachable from PID 1 --")
        for _, pid in ipairs(orphans) do
            local info = by_pid[pid]
            print(format("    %-8d %-20s %12d %10.2f",
                    info.pid, info.name, info.rss_kb, info.rss_kb / 1024))
        end
    end
end

-- ------------------------------------------------------------------------
-- Main dispatch
-- ------------------------------------------------------------------------
if tree_mode then
    print_tree()
else
    print_flat()
end
