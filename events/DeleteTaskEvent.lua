DeleteTaskEvent = {}
local DeleteTaskEvent_mt = Class(DeleteTaskEvent, Event)

InitEventClass(DeleteTaskEvent, "DeleteTaskEvent")

function DeleteTaskEvent.emptyNew()
    return Event.new(DeleteTaskEvent_mt)
end

function DeleteTaskEvent.new(groupId, taskId)
    local self = DeleteTaskEvent.emptyNew()
    self.groupId = groupId
    self.taskId = taskId
    return self
end

function DeleteTaskEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.groupId)
    streamWriteString(streamId, self.taskId)
end

function DeleteTaskEvent:readStream(streamId, connection)
    self.groupId = streamReadSring(streamId)
    self.taskId = streamReadSring(streamId)

    self:run(connection)
end

function DeleteTaskEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(DeleteTaskEvent.new(self.groupId, self.taskId))
    end

    if g_currentMission.todoList.taskGroups[self.groupId] == nil then
        print("DeleteTaskEvent: Group not present, skipping.")
        return
    end

    g_currentMission.todoList.taskGroups[self.groupId].tasks[self.taskId] = nil
    g_currentMission.todoList.activeTasks[self.taskId] = nil

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end
