local _M = {}
function _M.split(source, delimiters)
    local elements = {}
    local pattern = '([^'..delimiters..']+)'
    string.gsub(source, pattern, function(value) elements[#elements + 1] =     value;  end);
    return elements
end
return _M
