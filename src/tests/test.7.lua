local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

local PAGE_WIDTH = 80

local function center(text)
    text = text:gsub("^%s*(.-)%s*$", "%1")
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    return string.rep(" ", math.max(0, padding)) .. text
end

local function format(node)
    local out = {}
    local children = node.nodes or {}

    for _, child in ipairs(children) do
        if type(child) == "string" then
            out[#out + 1] = child:gsub("[\n\r\t]+", " ")
        elseif type(child) == "table" then
            local tag = (child.name or ""):lower()

            if tag == "link" and child.attributes and child.attributes.rel == "stylesheet" then
                out[#out + 1] = "   Link: " .. (child.attributes.rel or "") .. " " .. (child.attributes.hreflang or "") .. "\n"

            elseif tag == "h1" then
                local txt = child:getcontent() or ""
                if txt ~= "" then
                    out[#out + 1] = "\n\n" .. center(txt) .. "\n"
                end

            elseif tag == "ol" then
                local items = {}
                for _, sub in ipairs(child.nodes or {}) do
                    if type(sub) == "table" and (sub.name or ""):lower() == "li" then
                        local item_text = sub:getcontent() or ""
                        item_text = item_text:gsub("^%s+", ""):gsub("%s+$", "")
                        if item_text ~= "" then
                            items[#items + 1] = item_text
                        end
                    end
                end
                for i, item in ipairs(items) do
                    out[#out + 1] = "\n    " .. i .. ". " .. item
                end
                if #items > 0 then out[#out + 1] = "\n" end

            elseif tag == "ul" then
                local items = {}
                for _, sub in ipairs(child.nodes or {}) do
                    if type(sub) == "table" and (sub.name or ""):lower() == "li" then
                        local item_text = sub:getcontent() or ""
                        item_text = item_text:gsub("^%s+", ""):gsub("%s+$", "")
                        if item_text ~= "" then
                            items[#items + 1] = item_text
                        end
                    end
                end
                for _, item in ipairs(items) do
                    out[#out + 1] = "\n     * " .. item
                end
                if #items > 0 then out[#out + 1] = "\n" end

            elseif tag == "p" then
                local txt = child:getcontent() or ""
                txt = txt:gsub("^%s+", "")
                if txt ~= "" then
                    out[#out + 1] = "\n   " .. txt .. "\n"
                end

            elseif tag == "br" then
                out[#out + 1] = "\n   "

            elseif tag == "script" or tag == "style" or tag == "meta" then
                -- ignore

            else
                out[#out + 1] = format(child)
            end
        end
    end

    return table.concat(out)
end

local f = io.open("sample.html", "r")
if not f then
    print("Error: sample.html not found.")
    return
end
local content = f:read("*all")
f:close()

local root = htmlparser.parse(content)
local result = format(root)

result = result:gsub(" +", " ")
result = result:gsub("\n ", "\n")
result = result:gsub("\n\n\n+", "\n\n")
result = result:gsub("^%s+", "")

print(result)
