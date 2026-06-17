local script_path = arg[0]:match("(.*)[/\\]") or "./"; package.path = script_path .. "./lua-htmlparser/src/?.lua;" .. package.path

local htmlparser = require("htmlparser")

local PAGE_WIDTH = 70 -- Adjust for your terminal width

-- Helper: Centers text for headers
local function center(text)
    text = text:gsub("^%s*(.-)%s*$", "%1") -- trim
    local padding = math.floor((PAGE_WIDTH - #text) / 2)
    return string.rep(" ", math.max(0, padding)) .. text
end

-- Recursive function to extract all text and apply formatting
function format_tree(node, list_type, list_index)
    local output = ""
    
    for _, child in ipairs(node.nodes) do
        if type(child) == "string" then
            -- Found raw text! 
            -- We clean up HTML newlines/tabs so they don't break our plain text layout
            output = output .. child:gsub("[\n\r\t]+", " ")
        else
            local tag = child.name:lower()
            
            -- 1. Handle the "Link" requirement from <head>
            if tag == "link" and child.attributes.rel == "stylesheet" then
                output = output .. "   Link: " .. child.attributes.rel .. " " .. (child.attributes.hreflang or "") .. "\n"
            
            -- 2. Headers (Centered)
            elseif tag == "h1" then
                local header_text = format_tree(child)
                output = output .. "\n\n" .. center(header_text) .. "\n"
            
            -- 3. Lists (OL vs UL)
            elseif tag == "ol" then
                output = output .. format_tree(child, "ol", 0) .. "\n"
            elseif tag == "ul" then
                output = output .. format_tree(child, "ul") .. "\n"
            elseif tag == "li" then
                local item_content = format_tree(child):gsub("^%s+", "")
                if list_type == "ol" then
                    list_index = list_index + 1
                    output = output .. "\n    " .. list_index .. ". " .. item_content
                else
                    output = output .. "\n     * " .. item_content
                end

            -- 4. Paragraphs and Line Breaks
            elseif tag == "p" then
                output = output .. "\n   " .. format_tree(child):gsub("^%s+", "") .. "\n"
            elseif tag == "br" then
                output = output .. "\n   "

            -- 5. Ignore non-visible tags
            elseif tag == "script" or tag == "style" or tag == "meta" or tag == "head" then
                -- Do nothing
            
            -- 6. "Transparent" tags (span, a, section, body, html)
            -- We just want the text inside them without adding extra formatting
            else
                output = output .. format_tree(child, list_type, list_index)
            end
        end
    end
    
    return output
end

-- Execution logic
local f = io.open("sample.html", "r")
if f then
    local content = f:read("*all")
    f.close()

    local root = htmlparser.parse(content)
    local final_output = format_tree(root)

    -- Final Polish
    final_output = final_output:gsub(" +", " ")      -- Collapse multiple spaces
    final_output = final_output:gsub("\n ", "\n")    -- Remove spaces at start of lines
    final_output = final_output:gsub("\n\n\n+", "\n\n") -- Max 2 empty lines
    
    print(final_output)
else
    print("Error: sample.html not found.")
end
