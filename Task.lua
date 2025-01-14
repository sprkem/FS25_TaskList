Task = {}
local Group_mt = Class(Task)

Task.SHOULD_REPEAT_MODE = {
	MONTHLY = 1,
	DAILY = 2
}

Task.MAX_DETAIL_LENGTH = 40

function Task.new(customMt)
	local self = {}

	setmetatable(self, customMt or Group_mt)

    self.id = g_currentMission.todoList:generateId()
    self.detail = ""
    self.priority = 1
    self.period = 1
    self.shouldRecur = false
    self.shouldRecurMode = Task.SHOULD_REPEAT_MODE.MONTHLY

    return self
end

function Task:copyValuesFromTask(sourceTask)
    self.detail = sourceTask.detail
    self.priority = sourceTask.priority
    self.period = sourceTask.period
    self.shouldRecur = sourceTask.shouldRecur
    self.shouldRecurMode = sourceTask.shouldRecurMode
end

function Task:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteString(streamId, self.detail)
    streamWriteInt32(streamId, self.priority)
    streamWriteInt32(streamId, self.period)
    streamWriteBool(streamId, self.shouldRecur)
    streamWriteInt32(streamId, self.shouldRecurMode)
end

function Task:readStream(streamId, connection)
    self.id = streamReadSring(streamId)
    self.detail = streamReadSring(streamId)
    self.priority = streamReadInt32(streamId)
    self.period = streamReadInt32(streamId)
    self.shouldRecur = streamReadBool(streamId)
    self.shouldRecurMode = streamReadInt32(streamId)
end