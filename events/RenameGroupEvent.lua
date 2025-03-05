RenameGroupEvent = {}
local RenameGroupEvent_mt = Class(RenameGroupEvent, Event)

InitEventClass(RenameGroupEvent, "RenameGroupEvent")

function RenameGroupEvent.emptyNew()
    return Event.new(RenameGroupEvent_mt)
end

function RenameGroupEvent.new(groupId, newName)
    local self = RenameGroupEvent.emptyNew()
    self.groupId = groupId
    self.newName = newName
    return self
end

function RenameGroupEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.groupId)
    streamWriteString(streamId, self.newName)
end

function RenameGroupEvent:readStream(streamId, connection)
    self.groupId = streamReadString(streamId)
    self.newName = streamReadString(streamId)

    self:run(connection)
end

function RenameGroupEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(RenameGroupEvent.new(self.groupId, self.newName))
    end

    local group = g_currentMission.taskList.taskGroups[self.groupId]
    if group == nil then
        print("DeleteGroupEvent: Group not present, skipping.")
        return
    end

    group.name = self.newName

    local activeTaskUpdates = false
    for _, task in pairs(group.tasks) do
        local activeTask = g_currentMission.taskList.activeTasks[task.id]
        if activeTask ~= nil then
            activeTask.groupName = self.newName
            activeTaskUpdates = true
        end
    end

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    if activeTaskUpdates then
        g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    end
end
