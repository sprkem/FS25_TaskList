NewTaskEvent = {}
local NewTaskEvent_mt = Class(NewTaskEvent, Event)

InitEventClass(NewTaskEvent, "NewTaskEvent")

function NewTaskEvent.emptyNew()
    return Event.new(NewTaskEvent_mt)
end

function NewTaskEvent.new(groupId, task)
    local self = NewTaskEvent.emptyNew()
    self.groupId = groupId
    self.task = task
    return self
end

function NewTaskEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.groupId)
    self.task:writeStream(streamId, connection)
end

function NewTaskEvent:readStream(streamId, connection)
    self.groupId = streamReadString(streamId)

    self.task = Task.new()
    self.task:readStream(streamId, connection)

    self:run(connection)
end

function NewTaskEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(NewTaskEvent.new(self.groupId, self.task))
    end

    local group = g_currentMission.taskList.taskGroups[self.groupId]
    if group == nil then
        print("DeleteGroupEvent: Group not present, skipping.")
        return
    end

    group.tasks[self.task.id] = self.task

    local didAdd = false
    if group.type == TaskGroup.GROUP_TYPE.Template then
        for _, tg in pairs(g_currentMission.taskList.taskGroups) do
            if tg.type == TaskGroup.GROUP_TYPE.TemplateInstance and tg.templateGroupId == group.id then
                 if g_currentMission.taskList:checkAndAddActiveTaskIfDue(tg, self.task) then
                    didAdd = true
                 end
            end
        end
    elseif group.type == TaskGroup.GROUP_TYPE.Standard then
        didAdd = g_currentMission.taskList:checkAndAddActiveTaskIfDue(group, self.task)
    end

    if didAdd then
        g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    end

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
end
