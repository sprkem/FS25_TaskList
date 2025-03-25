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

    local tasks = group.tasks
    if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
        tasks = g_currentMission.taskList.taskGroups[group.templateGroupId].tasks
    end

    local activeTaskUpdates = false
    for _, task in pairs(tasks) do
        local key = group.id .. "_" .. task.id
        local activeTask = g_currentMission.taskList.activeTasks[key]

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
