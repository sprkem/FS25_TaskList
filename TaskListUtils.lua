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

function TaskListUtils.convertMonthNumberToPeriod(month)
    month = month - 2
    if month < 0 then
        month = month + 12
    end
    return month
end

function TaskListUtils.formatPeriodFullMonthName(period)
    if period == 1 then
        return g_i18n:getText("ui_month3")
    elseif period == 2 then
        return g_i18n:getText("ui_month4")
    elseif period == 3 then
        return g_i18n:getText("ui_month5")
    elseif period == 4 then
        return g_i18n:getText("ui_month6")
    elseif period == 5 then
        return g_i18n:getText("ui_month7")
    elseif period == 6 then
        return g_i18n:getText("ui_month8")
    elseif period == 7 then
        return g_i18n:getText("ui_month9")
    elseif period == 8 then
        return g_i18n:getText("ui_month10")
    elseif period == 9 then
        return g_i18n:getText("ui_month11")
    elseif period == 10 then
        return g_i18n:getText("ui_month12")
    elseif period == 11 then
        return g_i18n:getText("ui_month1")
    elseif period == 12 then
        return g_i18n:getText("ui_month2")
    end
end