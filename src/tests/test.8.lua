local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

local PAGE_WIDTH = 80

local function center(text)
    text = text:gsub("^%s*(.-)%s*$", "%1")
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    return string.rep(" ", math.max(0, padding)) .. text
end

local function format_node(node)
    local out = {}
    for _, child in ipairs(node.nodes or {}) do
        if type(child) == "string" then
            -- raw text (outside any tag)
            local txt = child:gsub("[\n\r\t]+", " ")
            if txt:match("%S") then
                out[#out + 1] = txt
            end
        elseif type(child) == "table" and child.name then
            local tag = child.name:lower()

            -- 1. Link from <head>
            if tag == "link" and child.attributes and child.attributes.rel == "stylesheet" then
                out[#out + 1] = "   Link: " .. (child.attributes.rel or "") .. " " .. (child.attributes.hreflang or "") .. "\n"

            -- 2. Headings (centered)
            elseif tag == "h1" then
                local txt = child:getcontent() or ""
                txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
                if txt ~= "" then
                    out[#out + 1] = "\n\n" .. center(txt) .. "\n"
                end

            -- 3. Ordered list
            elseif tag == "ol" then
                local items = {}
                for _, sub in ipairs(child.nodes or {}) do
                    if sub.name and sub.name:lower() == "li" then
                        local item_txt = sub:getcontent() or ""
                        item_txt = item_txt:gsub("^%s+", ""):gsub("%s+$", "")
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
                        local item_txt = sub:getcontent() or ""
                        item_txt = item_txt:gsub("^%s+", ""):gsub("%s+$", "")
                        if item_txt ~= "" then
                            items[#items + 1] = item_txt
                        end
                    end
                end
                for _, item in ipairs(items) do
                    out[#out + 1] = "\n     * " .. item
                end
                if #items > 0 then out[#out + 1] = "\n" end

            -- 5. Paragraphs
            elseif tag == "p" then
                local txt = child:getcontent() or ""
                txt = txt:gsub("^%s+", "")
                if txt ~= "" then
                    out[#out + 1] = "\n   " .. txt .. "\n"
                end

            -- 6. Line break
            elseif tag == "br" then
                out[#out + 1] = "\n   "

            -- 7. Ignored tags
            elseif tag == "script" or tag == "style" or tag == "meta" then
                -- skip

            -- 8. All other tags (body, html, div, span, a, etc.) – just recurse
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
local result = format_node(root)

-- Clean up excessive spacing
result = result:gsub(" +", " ")
result = result:gsub("\n ", "\n")
result = result:gsub("\n\n\n+", "\n\n")
result = result:gsub("^%s+", "")

print(result)
