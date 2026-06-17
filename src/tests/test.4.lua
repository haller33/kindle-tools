local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

local PAGE_WIDTH = 80

-- Helper: Centers text based on PAGE_WIDTH
local function center(text)
    text = text:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
    if #text == 0 then return "" end
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    return string.rep(" ", math.max(0, padding)) .. text
end

-- Function to process the tree recursively
local function process_node(node, list_type, list_index)
    local result = ""
    
    for _, child in ipairs(node.nodes) do
        if type(child) == "string" then
            -- Append raw text, cleaning up newlines within the HTML source
            result = result .. child:gsub("[\n\r]+", " "):gsub("%s+", " ")
        else
            local tag = child.name:lower()
            
            -- 1. Handle special specific tags
            if tag == "link" and child.attributes.rel == "stylesheet" then
                result = result .. "   Link: " .. child.attributes.rel .. " " .. (child.attributes.hreflang or "") .. "\n"
            
            elseif tag == "h1" then
                local header_text = process_node(child)
                result = result .. "\n" .. center(header_text) .. "\n"
            
            elseif tag == "ol" then
                result = result .. process_node(child, "ol", 0) .. "\n"
                
            elseif tag == "ul" then
                result = result .. process_node(child, "ul") .. "\n"
                
            elseif tag == "li" then
                local item_text = process_node(child):gsub("^%s+", "")
                if list_type == "ol" then
                    list_index = list_index + 1
                    result = result .. "\n    " .. list_index .. ". " .. item_text
                else
                    result = result .. "\n     * " .. item_text
                end
            
            elseif tag == "p" then
                result = result .. "\n   " .. process_node(child):gsub("^%s+", "") .. "\n"
                
            elseif tag == "br" then
                result = result .. "\n   "
                
            elseif tag == "script" or tag == "style" or tag == "meta" then
                -- Skip invisible tags
            
            else
                -- Inline tags (span, a, section) just pass their content through
                result = result .. process_node(child, list_type, list_index)
            end
        end
    end
    return result
end

-- Main Execution
local f = io.open("sample.html", "r")
if not f then print("File not found") return end
local html_content = f:read("*all")
f:close()

local root = htmlparser.parse(html_content)
local output = process_node(root)

-- Final Cleanup: Fix spacing and indentation
output = output:gsub(" +", " ") -- Collapse multiple spaces
output = output:gsub("\n ", "\n") -- Remove leading spaces after newlines
output = output:gsub("\n\n\n+", "\n\n") -- Max 2 newlines

print(output)
