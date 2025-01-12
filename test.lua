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


tasks = {}
tasks[1] = { id='1', name = 'field 1'}
tasks[2] = { id='2', name = 'field 2'}

local sortingFunction = function (k1, k2) return k1.name < k2.name end
table.sort(tasks, sortingFunction)

print(dump(tasks))