Task = {}
local Group_mt = Class(Task)

Task.shouldRepeat_MODE = {
	MONTH = 1,
	DAILY = 2
}

function Task.new(customMt)
	local self = {}

	setmetatable(self, customMt or Group_mt)

    self.id = g_currentMission.todoList:generateId()
    self.detail = ""
    self.priority = 1
    self.month = 1
    self.shouldRepeat = false
    self.shouldRepeatMode = Task.shouldRepeat_MODE.MONTH

    return self
end

function Task:copyValuesFromTask(sourceTask)
    self.detail = sourceTask.detail
    self.priority = sourceTask.priority
    self.month = sourceTask.month
    self.shouldRepeat = sourceTask.shouldRepeat
    self.shouldRepeatMode = sourceTask.shouldRepeatMode
end

function Task:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteString(streamId, self.detail)
    streamWriteInt32(streamId, self.priority)
    streamWriteInt32(streamId, self.month)
    streamWriteBool(streamId, self.shouldRepeat)
    streamWriteInt32(streamId, self.shouldRepeatMode)
end

function Task:readStream(streamId, connection)
    self.id = streamReadInt32(streamId)
    self.detail = streamReadSring(streamId)
    self.priority = streamReadInt32(streamId)
    self.month = streamReadInt32(streamId)
    self.shouldRepeat = streamReadBool(streamId)
    self.shouldRepeatMode = streamReadInt32(streamId)
end