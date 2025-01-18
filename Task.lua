Task = {}
local Group_mt = Class(Task)

Task.RECUR_MODE = {
    NONE = 0,
    MONTHLY = 1,
    DAILY = 2
}

Task.MAX_DETAIL_LENGTH = 45

function Task.new(customMt)
    local self = {}

    setmetatable(self, customMt or Group_mt)

    self.id = g_currentMission.taskList:generateId()
    self.detail = ""
    self.priority = 1
    self.period = 1
    self.shouldRecur = true
    self.recurMode = Task.RECUR_MODE.NONE

    return self
end

function Task:copyValuesFromTask(sourceTask)
    self.detail = sourceTask.detail
    self.priority = sourceTask.priority
    self.period = sourceTask.period
    self.shouldRecur = sourceTask.shouldRecur
    self.recurMode = sourceTask.recurMode
end

function Task:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteString(streamId, self.detail)
    streamWriteInt32(streamId, self.priority)
    streamWriteInt32(streamId, self.period)
    streamWriteBool(streamId, self.shouldRecur)
    streamWriteInt32(streamId, self.recurMode)
end

function Task:readStream(streamId, connection)
    self.id = streamReadSring(streamId)
    self.detail = streamReadSring(streamId)
    self.priority = streamReadInt32(streamId)
    self.period = streamReadInt32(streamId)
    self.shouldRecur = streamReadBool(streamId)
    self.recurMode = streamReadInt32(streamId)
end

function Task:saveToXmlFile(xmlFile, key)
    setXMLString(xmlFile, key .. "#id", self.id)
    setXMLString(xmlFile, key .. "#detail", self.detail)
    setXMLInt(xmlFile, key .. "#priority", self.priority)
    setXMLInt(xmlFile, key .. "#period", self.period)
    setXMLInt(xmlFile, key .. "#recurMode", self.recurMode)
    setXMLBool(xmlFile, key .. "#shouldRecur", self.shouldRecur)
end

function Task:loadFromXMLFile(xmlFile, key)
    self.id = getXMLString(xmlFile, key .. "#id")
    self.detail = getXMLString(xmlFile, key .. "#detail")
    self.priority = getXMLInt(xmlFile, key .. "#priority")
    self.period = getXMLInt(xmlFile, key .. "#period")
    self.recurMode = getXMLInt(xmlFile, key .. "#recurMode")
    self.shouldRecur = getXMLBool(xmlFile, key .. "#shouldRecur")
end
