local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

-- 1. Load the file
local f = io.open("sample.html", "r")
if not f then print("Could not open file!") return end
local content = f:read("*all")
f:close()

local root = htmlparser.parse(content)

-- 2. Formatting Function
function format_node(node)
    local result = ""

    -- If it's a text node (no tag name), just return the text
    if not node.name then
        return node:gettext()
    end

    -- Skip hidden content
    if node.name == "script" or node.name == "style" then
        return ""
    end

    -- Process children first
    for _, child in ipairs(node.nodes) do
        result = result .. format_node(child)
    end

    -- 3. Apply formatting based on the tag
    if node.name == "p" or node.name == "div" then
        result = "\n" .. result .. "\n"
    elseif node.name == "br" then
        result = result .. "\n"
    elseif node.name == "li" then
        result = "\n  • " .. result
    elseif node.name:match("h%d") then -- Matches h1, h2, etc.
        result = "\n\n" .. result:upper() .. "\n" .. string.rep("-", #result) .. "\n"
    end

    return result
end

-- 4. Execute on the body
local body = root:select("body")[1]
if body then
    local formatted_text = format_node(body)
    -- Clean up double/triple newlines for a tidier look
    formatted_text = formatted_text:gsub("\n\n\n+", "\n\n")
    print(formatted_text)
else
    print("No body tag found.")
end
