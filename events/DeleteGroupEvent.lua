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
    self.id = streamReadString(streamId)

    self:run(connection)
end

function DeleteGroupEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(DeleteGroupEvent.new(self.id))
    end

    local group = g_currentMission.taskList.taskGroups[self.id]
    if group == nil then
        print("DeleteGroupEvent: Group not present, skipping.")
        return
    end

    if group.type == TaskGroup.GROUP_TYPE.Template then
        -- Remove any template instances that use this tempate
        for _, g in pairs(g_currentMission.taskList.taskGroups) do
            if g.type == TaskGroup.GROUP_TYPE.TemplateInstance and g.templateGroupId == self.id then
                for _, task in pairs(group.tasks) do
                    local key = g.id .. "_" .. task.id
                    g_currentMission.taskList.activeTasks[key] = nil
                end
                g_currentMission.taskList.taskGroups[g.id] = nil
            end
        end
    end

    if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
        -- Remove any active tasks that are part of this template instance
        local templateGroup = g_currentMission.taskList.taskGroups[group.templateGroupId]
        if templateGroup then
            for _, task in pairs(templateGroup.tasks) do
                local key = group.id .. "_" .. task.id
                g_currentMission.taskList.activeTasks[key] = nil
            end
        end
    end

    -- Remove any active tasks for the group
    for _, task in pairs(group.tasks) do
        local key = group.id .. "_" .. task.id
        g_currentMission.taskList.activeTasks[key] = nil
    end

    g_currentMission.taskList.taskGroups[self.id] = nil

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end
