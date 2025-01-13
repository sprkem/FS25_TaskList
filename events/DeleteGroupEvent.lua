DeleteGroupEvent = {}
local DeleteGroupEvent_mt = Class(DeleteGroupEvent, Event)

InitEventClass(DeleteGroupEvent, "DeleteGroupEvent")

function DeleteGroupEvent.emptyNew()
    return Event.new(DeleteGroupEvent_mt)
end

function DeleteGroupEvent.new(id)
    local self = DeleteGroupEvent.emptyNew()
    self.id = id
    return self
end

function DeleteGroupEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
end

function DeleteGroupEvent:readStream(streamId, connection)
    self.id = streamWriteInt32(streamId, self.priority)

    self:run(connection)
end

function DeleteGroupEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(DeleteGroupEvent.new(self.id))
    end

    local group = g_currentMission.todoList.taskGroups[self.id]
    if group == nil then
        print("Group not present, skipping.")
        return
    end

    -- Remove any active tasks for the group
    for _, task in pairs(group.tasks) do
        g_currentMission.todoList.activeTasks[task.id] = nil
    end

    g_currentMission.todoList.taskGroups[self.id] = nil

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end
