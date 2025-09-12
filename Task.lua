Task = {}
local Group_mt = Class(Task)

Task.RECUR_MODE = {
    NONE = 0,
    MONTHLY = 1,
    DAILY = 2,
    EVERY_N_MONTHS = 3,
    EVERY_N_DAYS = 4
}

Task.TASK_TYPE = {
    Standard = 1,
    HusbandryFood = 2,
    HusbandryConditions = 3,
    Production = 4,
}

Task.MAX_DETAIL_LENGTH = 45
Task.TOTAL_FOOD_KEY = "total"

Task.EVALUATOR = {
    LessThan = 1,
    GreaterThan = 2,
}

Task.EVALUATOR_DESCRIPTION_STRINGS = {
    [Task.EVALUATOR.LessThan] = "ui_task_evaluator_less_than",
    [Task.EVALUATOR.GreaterThan] = "ui_task_evaluator_greater_than",
}

Task.EVALUATOR_SYMBOLS = {
    [Task.EVALUATOR.LessThan] = "<",
    [Task.EVALUATOR.GreaterThan] = ">",
}

Task.PRODUCTION_TYPE = {
    INPUT = 1,
    OUTPUT = 2,
}

function Task.new(customMt)
    local self = {}

    setmetatable(self, customMt or Group_mt)

    self.id = g_currentMission.taskList:generateId()
    self.detail = ""
    self.priority = 1
    self.period = 1
    self.effort = 1
    self.shouldRecur = true
    self.recurMode = Task.RECUR_MODE.NONE
    self.nextN = 0
    self.n = 0
    self.type = Task.TASK_TYPE.Standard
    self.husbandryFood = ""
    self.husbandryCondition = 0
    self.husbandryLevel = 0
    self.evaluator = Task.EVALUATOR.LessThan
    self.productionLevel = 0
    self.productionType = Task.PRODUCTION_TYPE.INPUT
    self.productionFillType = ""
    self.objectId = -1
    self.uniqueId = nil -- temp, used for lazily locating the objectId

    return self
end

function Task:getObjectId()
    -- Lazy load the objectId if it is not set after loading from XML
    if self.objectId == -1 then
        self.objectId = g_currentMission.taskList:getObjectIdFromUniqueId(self.uniqueId)
    end
    return self.objectId
end

function Task:getTaskDescription()
    local description = self.detail
    if self.type == Task.TASK_TYPE.HusbandryFood then
        local husbandry = g_currentMission.taskList:getHusbandries()[self:getObjectId()]
        if husbandry == nil then
            print("Task:getTaskDescription: husbandry is nil: " .. tostring(self:getObjectId()))
            description = 'N/A'
        else
            if self.husbandryFood == Task.TOTAL_FOOD_KEY then
                description = string.format("%s %s", husbandry.name, g_i18n:getText("ui_task_food_fill_total"))
            else
                local foodInfo = husbandry.keys[self.husbandryFood]
                description = string.format("%s %s %s", husbandry.name, g_i18n:getText("ui_task_food_fill"),
                    foodInfo.title)
            end
        end
    elseif self.type == Task.TASK_TYPE.HusbandryConditions then
        local husbandry = g_currentMission.taskList:getHusbandries()[self:getObjectId()]
        if husbandry == nil then
            print("Task:getTaskDescription: husbandry is nil: " .. tostring(self:getObjectId()))
            description = 'N/A'
        else
            local middleString = Task.EVALUATOR_DESCRIPTION_STRINGS[self.evaluator]
            local conditionInfo = husbandry.conditionInfos[self.husbandryCondition]
            description = string.format("%s %s %s", husbandry.name, g_i18n:getText(middleString),
                conditionInfo.title)
        end
    elseif self.type == Task.TASK_TYPE.Production then
        local production = g_currentMission.taskList:getProductions()[self:getObjectId()]
        local highOrLow = g_i18n:getText(Task.EVALUATOR_DESCRIPTION_STRINGS[self.evaluator])
        if production == nil then
            print("Task:getTaskDescription: production is nil: " .. tostring(self:getObjectId()))
            description = 'N/A'
        else
            if self.productionType == Task.PRODUCTION_TYPE.INPUT then
                local fillTypeName = production.inputs[self.productionFillType].title
                description = string.format("%s: %s %s %s", production.name, g_i18n:getText("ui_task_production_input"),
                    fillTypeName, highOrLow)
            else
                local fillTypeName = production.outputs[self.productionFillType].title
                description = string.format("%s: %s %s %s", production.name, g_i18n:getText("ui_task_production_output"),
                    fillTypeName, highOrLow)
            end
        end
    end
    return description
end

function Task:getEffortDescription(multiplier)
    if self.type == Task.TASK_TYPE.Standard then
        return tostring(self.effort * multiplier)
    end

    return '-'
end

function Task:getDueDescription(multiplier)
    if self.type == Task.TASK_TYPE.HusbandryFood then
        return string.format("< %s", g_i18n:formatVolume(self.husbandryLevel, 0))
    elseif self.type == Task.TASK_TYPE.HusbandryConditions then
        return string.format("%s %s", Task.EVALUATOR_SYMBOLS[self.evaluator], g_i18n:formatVolume(self.husbandryLevel, 0))
    elseif self.type == Task.TASK_TYPE.Production then
        return string.format("%s %s", Task.EVALUATOR_SYMBOLS[self.evaluator],
            g_i18n:formatVolume(self.productionLevel, 0))
    end

    local monthString = TaskListUtils.formatPeriodFullMonthName(self.period)
    if not self.shouldRecur then
        return monthString
    elseif self.recurMode == Task.RECUR_MODE.DAILY then
        return g_i18n:getText("ui_task_due_daily")
    elseif self.recurMode == Task.RECUR_MODE.MONTHLY then
        return string.format(g_i18n:getText("ui_task_due_monthly"), monthString)
    elseif self.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
        return string.format(g_i18n:getText("ui_task_due_n_days"), self.n)
    elseif self.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
        return string.format(g_i18n:getText("ui_task_due_n_months"), self.n)
    end
end

function Task:copyValuesFromTask(sourceTask, includeId)
    self.detail = sourceTask.detail
    self.priority = sourceTask.priority
    self.period = sourceTask.period
    self.effort = sourceTask.effort
    self.shouldRecur = sourceTask.shouldRecur
    self.recurMode = sourceTask.recurMode
    self.nextN = sourceTask.nextN
    self.n = sourceTask.n
    self.type = sourceTask.type
    self.husbandryFood = sourceTask.husbandryFood
    self.husbandryCondition = sourceTask.husbandryCondition
    self.husbandryLevel = sourceTask.husbandryLevel
    self.evaluator = sourceTask.evaluator
    self.productionLevel = sourceTask.productionLevel
    self.productionType = sourceTask.productionType
    self.productionFillType = sourceTask.productionFillType
    self.objectId = sourceTask.objectId
    self.uniqueId = sourceTask.uniqueId

    if includeId then
        self.id = sourceTask.id
    end
end

function Task:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteString(streamId, self.detail)
    streamWriteInt32(streamId, self.priority)
    streamWriteInt32(streamId, self.period)
    streamWriteBool(streamId, self.shouldRecur)
    streamWriteInt32(streamId, self.recurMode)
    streamWriteInt32(streamId, self.nextN)
    streamWriteInt32(streamId, self.n)
    streamWriteInt32(streamId, self.effort)
    streamWriteInt32(streamId, self.type)
    streamWriteString(streamId, self.husbandryFood)
    streamWriteInt32(streamId, self.husbandryCondition)
    streamWriteInt32(streamId, self.husbandryLevel)
    streamWriteInt32(streamId, self.evaluator)
    streamWriteInt32(streamId, self.productionLevel)
    streamWriteInt32(streamId, self.productionType)
    streamWriteString(streamId, self.productionFillType)

    if self:linksToPlaceable() then
        streamWriteInt32(streamId, self:getObjectId())
    else
        streamWriteInt32(streamId, -1)
    end
end

function Task:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self.detail = streamReadString(streamId)
    self.priority = streamReadInt32(streamId)
    self.period = streamReadInt32(streamId)
    self.shouldRecur = streamReadBool(streamId)
    self.recurMode = streamReadInt32(streamId)
    self.nextN = streamReadInt32(streamId)
    self.n = streamReadInt32(streamId)
    self.effort = streamReadInt32(streamId)
    self.type = streamReadInt32(streamId)
    self.husbandryFood = streamReadString(streamId)
    self.husbandryCondition = streamReadInt32(streamId)
    self.husbandryLevel = streamReadInt32(streamId)
    self.evaluator = streamReadInt32(streamId)
    self.productionLevel = streamReadInt32(streamId)
    self.productionType = streamReadInt32(streamId)
    self.productionFillType = streamReadString(streamId)
    self.objectId = streamReadInt32(streamId)
end

function Task:saveToXmlFile(xmlFile, key)
    setXMLString(xmlFile, key .. "#id", self.id)
    setXMLString(xmlFile, key .. "#detail", self.detail)
    setXMLInt(xmlFile, key .. "#priority", self.priority)
    setXMLInt(xmlFile, key .. "#period", self.period)
    setXMLInt(xmlFile, key .. "#recurMode", self.recurMode)
    setXMLBool(xmlFile, key .. "#shouldRecur", self.shouldRecur)
    setXMLInt(xmlFile, key .. "#nextN", self.nextN)
    setXMLInt(xmlFile, key .. "#n", self.n)
    setXMLInt(xmlFile, key .. "#effort", self.effort)
    setXMLInt(xmlFile, key .. "#type", self.type)
    setXMLString(xmlFile, key .. "#husbandryFood", self.husbandryFood)
    setXMLInt(xmlFile, key .. "#husbandryCondition", self.husbandryCondition)
    setXMLInt(xmlFile, key .. "#husbandryLevel", self.husbandryLevel)
    setXMLInt(xmlFile, key .. "#evaluator", self.evaluator)
    setXMLInt(xmlFile, key .. "#productionLevel", self.productionLevel)
    setXMLInt(xmlFile, key .. "#productionType", self.productionType)
    setXMLString(xmlFile, key .. "#productionFillType", self.productionFillType or "")

    if self:linksToPlaceable() then
        local uniqueId = NetworkUtil.getObject(self:getObjectId()).uniqueId
        setXMLString(xmlFile, key .. "#uniqueId", uniqueId)
    end
end

function Task:loadFromXMLFile(xmlFile, key)
    self.id = getXMLString(xmlFile, key .. "#id")
    self.detail = getXMLString(xmlFile, key .. "#detail")
    self.priority = getXMLInt(xmlFile, key .. "#priority")
    self.period = getXMLInt(xmlFile, key .. "#period")
    self.recurMode = getXMLInt(xmlFile, key .. "#recurMode")
    self.shouldRecur = getXMLBool(xmlFile, key .. "#shouldRecur")
    self.nextN = getXMLInt(xmlFile, key .. "#nextN")
    self.n = getXMLInt(xmlFile, key .. "#n")
    self.effort = getXMLInt(xmlFile, key .. "#effort") or 1
    self.type = getXMLInt(xmlFile, key .. "#type") or Task.TASK_TYPE.Standard
    self.husbandryFood = getXMLString(xmlFile, key .. "#husbandryFood") or ""
    self.husbandryCondition = getXMLInt(xmlFile, key .. "#husbandryCondition") or 0
    self.husbandryLevel = getXMLInt(xmlFile, key .. "#husbandryLevel") or 0
    self.evaluator = getXMLInt(xmlFile, key .. "#evaluator") or Task.EVALUATOR.LessThan
    self.productionLevel = getXMLInt(xmlFile, key .. "#productionLevel") or 0
    self.productionType = getXMLInt(xmlFile, key .. "#productionType") or Task.PRODUCTION_TYPE.INPUT
    self.productionFillType = getXMLString(xmlFile, key .. "#productionFillType") or ""

    self:postLoadFillTypeFix()

    if self:linksToPlaceable() then
        if self.type == Task.TASK_TYPE.HusbandryFood or self.type == Task.TASK_TYPE.HusbandryConditions then
            self.uniqueId = getXMLString(xmlFile, key .. "#husbandryId") or getXMLString(xmlFile, key .. "#uniqueId")
        elseif self.type == Task.TASK_TYPE.Production then
            self.uniqueId = getXMLString(xmlFile, key .. "#productionId") or getXMLString(xmlFile, key .. "#uniqueId")
        end
    end
end

-- Conversion from old method of storing fill types by id, to the new version of storing by name
function Task:postLoadFillTypeFix()
    if self:stringContainsNumber(self.husbandryFood) then
        local conversions = {
            ["115"] = "116", -- Hacky fix for when TMR id was changed from 115 to 116
        }
        local parts = {}
        for part in string.gmatch(self.husbandryFood, "[^_]+") do
            local fixedPart = conversions[part] or part
            local newPart = g_fillTypeManager.indexToName[tonumber(fixedPart)]
            table.insert(parts, newPart)
        end
        self.husbandryFood = table.concat(parts, "_")
        print("Converted husbandryFood to names: " .. self.husbandryFood)
    end

    if self:stringContainsNumber(self.productionFillType) then
        self.productionFillType = g_fillTypeManager.indexToName[tonumber(self.productionFillType)]
        if self.productionFillType ~= nil then
            print("Converted productionFillType to name: " .. self.productionFillType)
        end
    end
end

function Task:stringContainsNumber(string)
    return string:find("%d") ~= nil
end

function Task:linksToPlaceable()
    if self.type == Task.TASK_TYPE.HusbandryFood
        or self.type == Task.TASK_TYPE.HusbandryConditions
        or self.type == Task.TASK_TYPE.Production then
        return true
    end

    return false
end
