local script_path = debug.getinfo(1).source:match("@?(.*)[/\\]") or "./"; package.path = script_path .. "lua-htmlparser/src/?.lua;" .. package.path


local htmlparser = require("htmlparser")
local PAGE_WIDTH = 80

local function center(text)
    text = text:gsub("^%s*(.-)%s*$", "%1")
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    return string.rep(" ", math.max(0, padding)) .. text
end

-- Wrap a string to fit PAGE_WIDTH with a given indentation.
-- Returns a string with embedded newlines.
local function wrap(text, indent)
    if #text + #indent <= PAGE_WIDTH then return indent .. text end
    local result, start = {}, 1
    local space = " "
    while start <= #text do
        local max_len = PAGE_WIDTH - #indent
        if max_len <= 0 then
            result[#result+1] = indent .. text:sub(start)
            break
        end
        local finish = start + max_len - 1
        if finish >= #text then
            result[#result+1] = indent .. text:sub(start)
            break
        end
        -- find last space within limit
        local last_space = finish
        while last_space > start and text:sub(last_space, last_space) ~= space do
            last_space = last_space - 1
        end
        if last_space == start then last_space = finish end
        result[#result+1] = indent .. text:sub(start, last_space)
        start = last_space + 1
        while start <= #text and text:sub(start, start) == space do start = start + 1 end
    end
    return table.concat(result, "\n")
end

-- Remove all HTML tags and replace <br> with newline.
local function clean(raw)
    if not raw then return "" end
    raw = raw:gsub("<br%s*/?>", "\n")      -- <br> → newline
    raw = raw:gsub("<[^>]*>", "")          -- strip all other tags
    raw = raw:gsub(" +", " ")              -- collapse spaces
    raw = raw:gsub("\n +", "\n")
    return raw:match("^%s*(.-)%s*$") or "" -- trim
end

local function format(node)
    local out = {}
    for _, child in ipairs(node.nodes or {}) do
        if type(child) == "string" then
            local s = child:gsub("[\n\r\t]+", " ")
            if s:match("%S") then out[#out+1] = s end
        elseif child.name then
            local tag = child.name:lower()

            if tag == "link" and child.attributes and child.attributes.rel == "stylesheet" then
                out[#out+1] = "   Link: " .. child.attributes.rel .. " " .. (child.attributes.hreflang or "") .. "\n"

            elseif tag == "h1" then
                local txt = clean(child:getcontent())
                if txt ~= "" then out[#out+1] = "\n\n" .. center(txt) .. "\n" end

            elseif tag == "ol" then
                local items = {}
                for _, sub in ipairs(child.nodes or {}) do
                    if sub.name and sub.name:lower() == "li" then
                        local txt = clean(sub:getcontent())
                        if txt ~= "" then items[#items+1] = txt end
                    end
                end
                for i, txt in ipairs(items) do
                    out[#out+1] = "\n    " .. i .. ". " .. wrap(txt, "    " .. i .. ". ")
                end
                if #items > 0 then out[#out+1] = "\n" end

            elseif tag == "ul" then
                local items = {}
                for _, sub in ipairs(child.nodes or {}) do
                    if sub.name and sub.name:lower() == "li" then
                        local txt = clean(sub:getcontent())
                        if txt ~= "" then items[#items+1] = txt end
                    end
                end
                for _, txt in ipairs(items) do
                    out[#out+1] = "\n     * " .. wrap(txt, "     * ")
                end
                if #items > 0 then out[#out+1] = "\n" end

            elseif tag == "p" then
                local txt = clean(child:getcontent())
                if txt ~= "" then
                    -- handle <br> induced newlines
                    local paras = {}
                    for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
                        if line ~= "" then paras[#paras+1] = wrap(line, "   ") end
                    end
                    out[#out+1] = "\n   " .. table.concat(paras, "\n   ") .. "\n"
                end

            elseif tag == "br" then
                out[#out+1] = "\n   "

            elseif tag ~= "script" and tag ~= "style" and tag ~= "meta" then
                out[#out+1] = format(child)
            end
        end
    end
    return table.concat(out)
end

local f = io.open("sample.html", "r")
if not f then error("sample.html not found") end
local content = f:read("*all")
f:close()

local root = htmlparser.parse(content)
local result = format(root)

-- final cleanup of excessive blank lines and spaces
result = result:gsub(" +", " "):gsub("\n ", "\n"):gsub("\n\n\n+", "\n\n"):gsub("^%s+", "")
print(result)
