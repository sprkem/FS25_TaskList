NewTaskGroupEvent = {}
local NewTaskGroupEvent_mt = Class(NewTaskGroupEvent, Event)

InitEventClass(NewTaskGroupEvent, "NewTaskGroupEvent")

function NewTaskGroupEvent.emptyNew()
    return Event.new(NewTaskGroupEvent_mt)
end

function NewTaskGroupEvent.new(taskGroup)
    local self = NewTaskGroupEvent.emptyNew()
    self.taskGroup = taskGroup
    return self
end

function NewTaskGroupEvent:writeStream(streamId, connection)
    self.taskGroup:writeStream(streamId, connection)
end

function NewTaskGroupEvent:readStream(streamId, connection)
    self.taskGroup = TaskGroup.new()
    self.taskGroup:readStream(streamId, connection)

    self:run(connection)
end

function NewTaskGroupEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(NewTaskGroupEvent.new(self.taskGroup))
    end
    g_currentMission.todoList.taskGroups[self.taskGroup.id] = self.taskGroup
    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_currentMission.todoList:addGroupTasksForCurrentMonth(self.taskGroup)
end
