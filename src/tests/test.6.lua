local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

local PAGE_WIDTH = 80

-- Helper: Centers text for headers
local function center(text)
    text = text:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    return string.rep(" ", math.max(0, padding)) .. text
end

-- Function to traverse the tree and extract/format text
function walk(node, list_type, list_index)
    local output = ""
    
    -- In this library, node.nodes contains both child tags (tables) and text (strings)
    for _, child in ipairs(node.nodes) do
        if type(child) == "string" then
            -- Clean up HTML whitespace/newlines
            output = output .. child:gsub("[\n\r\t]+", " ")
        else
            local tag = (child.name or ""):lower()
            
            -- 1. Handle the specific "Link" requirement from the <head>
            if tag == "link" and child.attributes.rel == "stylesheet" then
                output = output .. "   Link: " .. (child.attributes.rel or "") .. " " .. (child.attributes.hreflang or "") .. "\n"
            
            -- 2. Headers (Centered)
            elseif tag == "h1" then
                local header_text = walk(child)
                output = output .. "\n\n" .. center(header_text) .. "\n"
            
            -- 3. Lists (Ordered vs Unordered)
            elseif tag == "ol" then
                output = output .. walk(child, "ol", 0) .. "\n"
            elseif tag == "ul" then
                output = output .. walk(child, "ul") .. "\n"
            elseif tag == "li" then
                local item_content = walk(child):gsub("^%s+", "")
                if list_type == "ol" then
                    list_index = list_index + 1
                    output = output .. "\n    " .. list_index .. ". " .. item_content
                else
                    output = output .. "\n     * " .. item_content
                end

            -- 4. Paragraphs and Line Breaks
            elseif tag == "p" then
                output = output .. "\n   " .. walk(child):gsub("^%s+", "") .. "\n"
            elseif tag == "br" then
                output = output .. "\n   "

            -- 5. Logic for hidden/inline tags
            elseif tag == "script" or tag == "style" or tag == "meta" then
                -- Ignore entirely
            else
                -- Transparent tags (span, a, section, body, html)
                -- We just want the text inside them without adding new formatting
                output = output .. walk(child, list_type, list_index)
            end
        end
    end
    
    return output
end

-- Main execution logic
local f = io.open("sample.html", "r")
if f then
    local content = f:read("*all")
    f.close()

    local root = htmlparser.parse(content)
    
    -- We process from root to ensure we catch the <head> links
    local final_text = walk(root)

    -- CLEANUP: Polish the spacing to match the requested look
    final_text = final_text:gsub(" +", " ")          -- Collapse multiple spaces
    final_text = final_text:gsub("\n ", "\n")        -- Remove leading space on new lines
    final_text = final_text:gsub("\n\n\n+", "\n\n")  -- Max 2 consecutive newlines
    final_text = final_text:gsub("^%s+", "")         -- Trim start
    
    print(final_text)
else
    print("Error: sample.html not found.")
end
