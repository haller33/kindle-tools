local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

local PAGE_WIDTH = 80

local function center(text)
    text = text:gsub("^%s*(.-)%s*$", "%1")
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    return string.rep(" ", math.max(0, padding)) .. text
end

-- Wrap text to a specific width, preserving existing indentation
local function wrap_text(text, indent)
    indent = indent or ""
    local result = {}
    local line_start = 1
    local text_len = #text
    
    while line_start <= text_len do
        -- Find the end of the current line (up to PAGE_WIDTH - indent length)
        local max_width = PAGE_WIDTH - #indent
        if max_width <= 0 then
            result[#result + 1] = indent .. text:sub(line_start)
            break
        end
        
        local line_end = line_start + max_width - 1
        if line_end >= text_len then
            result[#result + 1] = indent .. text:sub(line_start)
            break
        end
        
        -- Try to break at a space
        local break_at = line_end
        while break_at > line_start and text:sub(break_at, break_at) ~= " " do
            break_at = break_at - 1
        end
        
        if break_at == line_start then
            -- No space found, force break
            break_at = line_end
        end
        
        result[#result + 1] = indent .. text:sub(line_start, break_at)
        line_start = break_at + 1
        -- Skip leading spaces on next line
        while line_start <= text_len and text:sub(line_start, line_start) == " " do
            line_start = line_start + 1
        end
    end
    
    return table.concat(result, "\n")
end

-- Clean HTML tags from text, converting <br> to newlines
local function clean_text(txt)
    if not txt then return "" end
    -- Replace <br>, <br/>, <br /> with newline
    txt = txt:gsub("<br%s*/?>", "\n")
    -- Remove all other HTML tags
    txt = txt:gsub("<[^>]*>", "")
    -- Collapse multiple spaces
    txt = txt:gsub(" +", " ")
    txt = txt:gsub("\n +", "\n")
    txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
    return txt
end

local function format_node(node)
    local out = {}
    for _, child in ipairs(node.nodes or {}) do
        if type(child) == "string" then
            local txt = child:gsub("[\n\r\t]+", " ")
            if txt:match("%S") then
                out[#out + 1] = txt
            end
        elseif type(child) == "table" and child.name then
            local tag = child.name:lower()

            -- 1. Link from <head>
            if tag == "link" and child.attributes and child.attributes.rel == "stylesheet" then
                out[#out + 1] = "   Link: " .. (child.attributes.rel or "") .. " " .. (child.attributes.hreflang or "") .. "\n"

            -- 2. Headings (centered) - already at 80 chars
            elseif tag == "h1" then
                local txt = clean_text(child:getcontent())
                if txt ~= "" then
                    out[#out + 1] = "\n\n" .. center(txt) .. "\n"
                end

            -- 3. Ordered list
            elseif tag == "ol" then
                local items = {}
                for _, sub in ipairs(child.nodes or {}) do
                    if sub.name and sub.name:lower() == "li" then
                        local item_txt = clean_text(sub:getcontent())
                        if item_txt ~= "" then
                            items[#items + 1] = item_txt
                        end
                    end
                end
                for i, item in ipairs(items) do
                    out[#out + 1] = "\n    " .. i .. ". " .. item
                end
                if #items > 0 then out[#out + 1] = "\n" end

            -- 4. Unordered list
            elseif tag == "ul" then
                local items = {}
                for _, sub in ipairs(child.nodes or {}) do
                    if sub.name and sub.name:lower() == "li" then
                        local item_txt = clean_text(sub:getcontent())
                        if item_txt ~= "" then
                            items[#items + 1] = item_txt
                        end
                    end
                end
                for _, item in ipairs(items) do
                    out[#out + 1] = "\n     * " .. item
                end
                if #items > 0 then out[#out + 1] = "\n" end

            -- 5. Paragraphs (will be wrapped later)
            elseif tag == "p" then
                local txt = clean_text(child:getcontent())
                if txt ~= "" then
                    -- Replace newlines from <br> with actual line breaks
                    txt = txt:gsub("\n", "\n   ")
                    out[#out + 1] = "\n   " .. txt .. "\n"
                end

            -- 6. Line break
            elseif tag == "br" then
                out[#out + 1] = "\n   "

            -- 7. Ignored tags
            elseif tag == "script" or tag == "style" or tag == "meta" then
                -- skip

            -- 8. All other tags
            else
                out[#out + 1] = format_node(child)
            end
        end
    end
    return table.concat(out)
end

-- Read and parse the HTML file
local f = io.open("sample.html", "r")
if not f then
    print("Error: sample.html not found.")
    return
end
local content = f:read("*all")
f:close()

local root = htmlparser.parse(content)
local raw_result = format_node(root)

-- Clean up excessive spacing
raw_result = raw_result:gsub(" +", " ")
raw_result = raw_result:gsub("\n ", "\n")
raw_result = raw_result:gsub("\n\n\n+", "\n\n")
raw_result = raw_result:gsub("^%s+", "")

-- Now wrap each paragraph while preserving list items and headers
local lines = {}
for line in raw_result:gmatch("[^\n]*") do
    -- Skip empty lines (preserve them as separators)
    if line == "" then
        lines[#lines + 1] = ""
    else
        -- Check if this line is a header (centered) or list item (starts with spaces + number or *)
        if line:match("^%s+[%d]+%.") or line:match("^%s+%*") then
            -- List item: wrap the content after the bullet/number
            local prefix = line:match("^(%s+[%d]+%.%s+)") or line:match("^(%s+%*%s+)")
            if prefix then
                local content = line:sub(#prefix + 1)
                lines[#lines + 1] = prefix .. wrap_text(content, prefix)
            else
                lines[#lines + 1] = line
            end
        elseif line:match("^%s+Link:") then
            -- Link line: keep as is
            lines[#lines + 1] = line
        elseif line:match("^%s+") and not line:match("^%s*$") then
            -- Indented paragraph (like the acknowledgements paragraph)
            local indent = line:match("^(%s+)") or ""
            local content = line:sub(#indent + 1)
            lines[#lines + 1] = wrap_text(content, indent)
        else
            -- Regular paragraph
            lines[#lines + 1] = wrap_text(line, "")
        end
    end
end

-- Join lines, but ensure we don't add extra blank lines
local final_result = {}
local last_was_empty = false
for _, line in ipairs(lines) do
    if line == "" then
        if not last_was_empty then
            final_result[#final_result + 1] = ""
            last_was_empty = true
        end
    else
        final_result[#final_result + 1] = line
        last_was_empty = false
    end
end

print(table.concat(final_result, "\n"))
