math.randomseed(os.time())
local function generateId()
    local template ='xxxxxxxx-xxxx-xxxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

input = ' hellow world '
local a = { "A", "B", "C"}


print(next(a))
print(next(a))