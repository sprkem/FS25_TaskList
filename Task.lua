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
    Husbandry = 2,
}

Task.MAX_DETAIL_LENGTH = 45

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
    self.husbandryId = -1
    self.husbandryFood = ""
    self.husbandryLevel = 0

    return self
end

function Task:getTaskDescription()
    local description = self.detail
    if self.type == Task.TASK_TYPE.Husbandry then
        local husbandry = g_currentMission.taskList:getHusbandries()[self.husbandryId]
        local foodInfo = husbandry.keys[self.husbandryFood]
        description = string.format("%s %s %s", husbandry.name, g_i18n:getText("ui_task_food_fill"), foodInfo.title)
    end
    return description
end

function Task:getEffortDescription(multiplier)
    local effortDescription = tostring(self.effort * multiplier)
    if self.type == Task.TASK_TYPE.Husbandry then
        effortDescription = '-'
    end
    return effortDescription
end

function Task:getDueDescription(multiplier)
    if self.type == Task.TASK_TYPE.Husbandry then
        return string.format("< %s", g_i18n:formatVolume(self.husbandryLevel, 0))
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
    self.husbandryId = sourceTask.husbandryId
    self.husbandryFood = sourceTask.husbandryFood
    self.husbandryLevel = sourceTask.husbandryLevel

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
    streamWriteInt32(streamId, self.husbandryId)
    streamWriteString(streamId, self.husbandryFood)
    streamWriteInt32(streamId, self.husbandryLevel)
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
    self.husbandryId = streamReadInt32(streamId)
    self.husbandryFood = streamReadString(streamId)
    self.husbandryLevel = streamReadInt32(streamId)
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
    setXMLInt(xmlFile, key .. "#husbandryId", self.husbandryId)
    setXMLString(xmlFile, key .. "#husbandryFood", self.husbandryFood)
    setXMLInt(xmlFile, key .. "#husbandryLevel", self.husbandryLevel)
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
    self.husbandryId = getXMLInt(xmlFile, key .. "#husbandryId") or -1
    self.husbandryFood = getXMLString(xmlFile, key .. "#husbandryFood") or ""
    self.husbandryLevel = getXMLInt(xmlFile, key .. "#husbandryLevel") or 0
    self:repairAfterLoad()
end

function Task:repairAfterLoad()
    -- Account for previous localised method of storing food type
    for _, animalFood in pairs(g_currentMission.animalFoodSystem.animalFood) do
        for _, group in animalFood.groups do
            if self.husbandryFood == group.title then
                print('Repaired ' .. group.title)
                self.husbandryFood = g_currentMission.taskList:getHusbandryFoodKey(group)
                break
            end
        end
    end
end
