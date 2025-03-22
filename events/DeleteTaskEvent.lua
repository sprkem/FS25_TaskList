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
    self.groupId = streamReadString(streamId)
    self.taskId = streamReadString(streamId)

    self:run(connection)
end

function DeleteTaskEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(DeleteTaskEvent.new(self.groupId, self.taskId))
    end

    if g_currentMission.taskList.taskGroups[self.groupId] == nil then
        print("DeleteTaskEvent: Group not present, skipping.")
        return
    end

    local group = g_currentMission.taskList.taskGroups[self.groupId]

    g_currentMission.taskList.taskGroups[self.groupId].tasks[self.taskId] = nil
    local key = self.groupId .. "_" .. self.taskId
    g_currentMission.taskList.activeTasks[key] = nil

    if group.type == TaskGroup.GROUP_TYPE.Template then
        for _, tg in pairs(g_currentMission.taskList.taskGroups) do
            if tg.type == TaskGroup.GROUP_TYPE.TemplateInstance and tg.templateGroupId == group.id then
                local key = tg.id .. "_" .. self.taskId
                g_currentMission.taskList.activeTasks[key] = nil
            end
        end
    end

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end
