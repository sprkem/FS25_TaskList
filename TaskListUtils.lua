TaskListUtils = {}

function TaskListUtils.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[TaskListUtils.deepcopy(orig_key)] = TaskListUtils.deepcopy(orig_value)
        end
        setmetatable(copy, TaskListUtils.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end