CompleteTaskEvent = {}
local CompleteTaskEvent_mt = Class(CompleteTaskEvent, Event)

InitEventClass(CompleteTaskEvent, "CompleteTaskEvent")

function CompleteTaskEvent.emptyNew()
    return Event.new(CompleteTaskEvent_mt)
end

function CompleteTaskEvent.new(id)
    local self = CompleteTaskEvent.emptyNew()
    self.id = id
    return self
end

function CompleteTaskEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
end

function CompleteTaskEvent:readStream(streamId, connection)
    self.id = streamWriteInt32(streamId)

    self:run(connection)
end

function CompleteTaskEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(CompleteTaskEvent.new(self.id))
    end

    g_currentMission.todoList.activeTasks[self.id] = nil
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end
