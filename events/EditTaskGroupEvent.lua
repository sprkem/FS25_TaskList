EditTaskGroupEvent = {}
local EditTaskGroupEvent_mt = Class(EditTaskGroupEvent, Event)

InitEventClass(EditTaskGroupEvent, "EditTaskGroupEvent")

function EditTaskGroupEvent.emptyNew()
    return Event.new(EditTaskGroupEvent_mt)
end

function EditTaskGroupEvent.new(taskGroup)
    local self = EditTaskGroupEvent.emptyNew()
    self.taskGroup = taskGroup
    return self
end

function EditTaskGroupEvent:writeStream(streamId, connection)
    self.taskGroup:writeStream(streamId, connection)
end

function EditTaskGroupEvent:readStream(streamId, connection)
    self.taskGroup = TaskGroup.new()
    self.taskGroup:readStream(streamId, connection)

    self:run(connection)
end

function EditTaskGroupEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(EditTaskGroupEvent.new(self.taskGroup))
    end

    local group = g_currentMission.taskList.taskGroups[self.taskGroup.id]
    if group == nil then
        print("EditTaskGroupEvent: Group not present, skipping.")
        return
    end

    group:copyValuesFromGroup(self.taskGroup, false)

    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_currentMission.taskList:addGroupTasksForCurrentPeriod(self.taskGroup)
    g_currentMission.taskList:addDailyTasks(self.taskGroup)
end
