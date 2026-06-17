local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

-- Function to read file content
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f.close()
    return content
end

-- Configuration for formatting
local format_rules = {
    h1 = function(t) return "\n\n" .. t:upper() .. "\n" .. string.rep("=", #t) .. "\n" end,
    h2 = function(t) return "\n\n" .. t:upper() .. "\n" .. string.rep("-", #t) .. "\n" end,
    h3 = function(t) return "\n\n### " .. t .. "\n" end,
    p  = function(t) return "\n" .. t .. "\n" end,
    br = function(t) return "\n" end,
    li = function(t) return "\n  • " .. t end,
    strong = function(t) return "*" .. t .. "*" end,
    em = function(t) return "_" .. t .. "_" end,
    a  = function(t, node) 
        local href = node.attributes and node.attributes.href or ""
        return t .. " [" .. href .. "]" 
    end
}

function convert_to_text(node)
    local output = ""

    -- 1. Handle Text Nodes (In lua-htmlparser, text nodes have no 'name')
    if not node.name then
        return node:gettext()
    end

    -- 2. Skip non-visible content
    if node.name == "script" or node.name == "style" or node.name == "head" then
        return ""
    end

    -- 3. Recursively process all children first
    for _, child in ipairs(node.nodes) do
        output = output .. convert_to_text(child)
    end

    -- 4. Apply formatting based on the tag name
    local formatter = format_rules[node.name:lower()]
    if formatter then
        output = formatter(output, node)
    elseif node.name == "div" then
        output = "\n" .. output .. "\n"
    end

    return output
end

-- MAIN EXECUTION
local html_content = read_file("sample.html")

if html_content then
    local root = htmlparser.parse(html_content)
    
    -- Select the body or the whole root if body is missing
    local body = root:select("body")[1] or root
    local plain_text = convert_to_text(body)

    -- Clean up whitespace: 
    -- Collapse 3+ newlines into 2, and trim leading/trailing space
    plain_text = plain_text:gsub("\n%s*\n%s*\n+", "\n\n")
    plain_text = plain_text:gsub("^%s+", ""):gsub("%s+$", "")

    print(plain_text)
else
    print("Error: Could not read file.html")
end
