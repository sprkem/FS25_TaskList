TaskListUtils = {}
local g_currentModName = g_currentModName

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
    if month <= 0 then
        month = month + 12
    end
    return month
end

function TaskListUtils.convertPeriodToMonthNumber(period)
    period = period + 2
    if period > 12 then
        period = period - 12
    end
    return period
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

-- Courtesy of PowerTools
function TaskListUtils.showOptionDialog(parameters)
    OptionDialog.createFromExistingGui({
        options = parameters.options,
        optionText = parameters.text,
        optionTitle = parameters.title,
        callbackFunc = parameters.callback,
    }, parameters.name or g_currentModName .. "OptionDialog")

    local optionDialog = OptionDialog.INSTANCE

    if parameters.okButtonText ~= nil or parameters.cancelButtonText ~= nil then
        optionDialog:setButtonTexts(parameters.okButtonText, parameters.cancelButtonText)
    end

    local defaultOption = parameters.defaultOption or 1

    optionDialog.optionElement:setState(defaultOption)

    if parameters.callback and (type(parameters.callback)) == "function" then
        optionDialog:setCallback(parameters.callback, parameters.target, parameters.args)
    end
end

-- Courtesy of PowerTools
function TaskListUtils.showTextInputDialog(parameters)
    local textInputDialog = TextInputDialog.new()
    local imePrompt = nil

    if parameters.isPasswordDialog then
        g_gui:loadGui("dataS/gui/dialogs/PasswordDialog.xml", "TextInputDialog", textInputDialog)
    else
        g_gui:loadGui("dataS/gui/dialogs/TextInputDialog.xml", "TextInputDialog", textInputDialog)
    end

    if parameters.callback and (type(parameters.callback)) == "function" then
        textInputDialog:setCallback(parameters.callback, parameters.target, parameters.defaultText, parameters.text,
            imePrompt, parameters.maxCharacters, parameters.args, parameters.isPasswordDialog, parameters.disableFilter)
    end

    if parameters.okButtonText ~= nil or parameters.cancelButtonText ~= nil then
        textInputDialog:setButtonTexts(parameters.okButtonText, parameters.cancelButtonText)
    end

    textInputDialog:setTitle(parameters.title or "") --NOTE: title is not used yet

    local textHeight, _ = textInputDialog.dialogTextElement:getTextHeight()
    textInputDialog:resizeDialog(textHeight)

    textInputDialog:show()
end

TaskListUtils.taskSortingFunction = function(t1, t2)
    if t1.period == nil or t2.period == nil then
        return false
    end

    if t1.period == t2.period then
        return t1.priority < t2.priority
    end
    return t1.period < t2.period
end
