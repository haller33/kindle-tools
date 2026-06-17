local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")
local PAGE_WIDTH = 80

-- Pre-bind frequently used functions for speed
local gsub = string.gsub
local sub = string.sub
local rep = string.rep
local concat = table.concat
local insert = table.insert
local match = string.match
local find = string.find

local function center(text)
    text = match(text, "^%s*(.-)%s*$") or ""
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    if padding < 0 then padding = 0 end
    return rep(" ", padding) .. text
end

-- Wrap a string to PAGE_WIDTH with given indentation (indent is a string).
-- Returns a string with embedded newlines (no trailing newline).
local function wrap(text, indent)
    local indent_len = #indent
    if #text + indent_len <= PAGE_WIDTH then
        return indent .. text
    end
    local parts = {}
    local start = 1
    local text_len = #text
    while start <= text_len do
        local max_len = PAGE_WIDTH - indent_len
        if max_len <= 0 then
            parts[#parts+1] = indent .. sub(text, start)
            break
        end
        local finish = start + max_len - 1
        if finish >= text_len then
            parts[#parts+1] = indent .. sub(text, start)
            break
        end
        -- find last space within [start, finish]
        local last_space = finish
        while last_space > start and sub(text, last_space, last_space) ~= " " do
            last_space = last_space - 1
        end
        if last_space == start then
            last_space = finish
        end
        parts[#parts+1] = indent .. sub(text, start, last_space)
        start = last_space + 1
        -- skip any following spaces
        while start <= text_len and sub(text, start, start) == " " do
            start = start + 1
        end
    end
    return concat(parts, "\n")
end

-- Remove HTML tags, convert <br> variants to newline, collapse spaces.
local function clean(raw)
    if not raw then return "" end
    -- <br> -> newline, then strip all other tags, then clean whitespace
    local s = gsub(raw, "<br%s*/?>", "\n")
    s = gsub(s, "<[^>]*>", "")
    s = gsub(s, "%s+", " ")
    s = gsub(s, "\n ", "\n")
    return match(s, "^%s*(.-)%s*$") or ""
end

local function format(node)
    local out = {}
    local children = node.nodes or {}
    for i = 1, #children do
        local child = children[i]
        if type(child) == "string" then
            local s = gsub(child, "[\n\r\t]+", " ")
            if match(s, "%S") then
                insert(out, s)
            end
        elseif child.name then
            local tag = child.name:lower()

            if tag == "link" and child.attributes and child.attributes.rel == "stylesheet" then
                insert(out, "   Link: " .. child.attributes.rel .. " " .. (child.attributes.hreflang or "") .. "\n")

            elseif tag == "h1" then
                local txt = clean(child:getcontent())
                if txt ~= "" then
                    insert(out, "\n\n" .. center(txt) .. "\n")
                end

            elseif tag == "ol" then
                local num = 1
                for _, sub in ipairs(child.nodes or {}) do
                    if sub.name and sub.name:lower() == "li" then
                        local txt = clean(sub:getcontent())
                        if txt ~= "" then
                            local prefix = "    " .. num .. ". "
                            insert(out, "\n" .. wrap(txt, prefix))
                            num = num + 1
                        end
                    end
                end
                if num > 1 then insert(out, "\n") end

            elseif tag == "ul" then
                for _, sub in ipairs(child.nodes or {}) do
                    if sub.name and sub.name:lower() == "li" then
                        local txt = clean(sub:getcontent())
                        if txt ~= "" then
                            insert(out, "\n     * " .. wrap(txt, "     * "))
                        end
                    end
                end
                if #(child.nodes or {}) > 0 then insert(out, "\n") end

            elseif tag == "p" then
                local txt = clean(child:getcontent())
                if txt ~= "" then
                    local first = true
                    for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
                        if line ~= "" then
                            local wrapped = wrap(line, "   ")
                            if first then
                                insert(out, "\n   " .. wrapped)
                                first = false
                            else
                                insert(out, "\n   " .. wrapped)
                            end
                        end
                    end
                    insert(out, "\n")
                end

            elseif tag == "br" then
                insert(out, "\n   ")

            elseif tag ~= "script" and tag ~= "style" and tag ~= "meta" then
                insert(out, format(child))
            end
        end
    end
    return concat(out)
end

local f = io.open("sample.html", "r")
if not f then error("sample.html not found") end
local content = f:read("*all")
f:close()

local root = htmlparser.parse(content)
local result = format(root)

-- Final cleanup: collapse multiple spaces, fix newline+space, limit blank lines to two.
result = gsub(result, " +", " ")
result = gsub(result, "\n ", "\n")
result = gsub(result, "\n\n\n+", "\n\n")
result = gsub(result, "^%s+", "")
print(result)
