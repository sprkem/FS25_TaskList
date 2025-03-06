EditTaskEvent = {}
local EditTaskEvent_mt = Class(EditTaskEvent, Event)

InitEventClass(EditTaskEvent, "EditTaskEvent")

function EditTaskEvent.emptyNew()
    return Event.new(EditTaskEvent_mt)
end

function EditTaskEvent.new(groupId, task)
    local self = EditTaskEvent.emptyNew()
    self.groupId = groupId
    self.task = task
    return self
end

function EditTaskEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.groupId)
    self.task:writeStream(streamId, connection)
end

function EditTaskEvent:readStream(streamId, connection)
    self.groupId = streamReadString(streamId)
    self.task = Task.new()
    self.task:readStream(streamId, connection)

    self:run(connection)
end

function EditTaskEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(EditTaskEvent.new(self.groupId, self.task))
    end

    local group = g_currentMission.taskList.taskGroups[self.groupId]
    if group == nil then
        print("DeleteGroupEvent: Group not present, skipping.")
        return
    end

    group.tasks[self.task.id]:copyValuesFromTask(self.task, false)

    local didAdd = g_currentMission.taskList:checkAndAddActiveTaskIfDue(group.id, self.task)
    if didAdd then
        g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    end

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
end
