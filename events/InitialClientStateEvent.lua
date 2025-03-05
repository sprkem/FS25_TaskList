InitialClientStateEvent = {}
local InitialClientStateEvent_mt = Class(InitialClientStateEvent, Event)

InitEventClass(InitialClientStateEvent, "InitialClientStateEvent")

function InitialClientStateEvent.emptyNew()
    return Event.new(InitialClientStateEvent_mt)
end

function InitialClientStateEvent.new()
    return InitialClientStateEvent.emptyNew()
end

function InitialClientStateEvent:writeStream(streamId, connection)
    local groupCount = 0
    for _ in pairs(g_currentMission.taskList.taskGroups) do groupCount = groupCount + 1 end
    streamWriteInt32(streamId, groupCount)

    for _, group in pairs(g_currentMission.taskList.taskGroups) do
        group:writeStream(streamId, connection)
    end

    local activeTaskCount = 0
    for _ in pairs(g_currentMission.taskList.activeTasks) do activeTaskCount = activeTaskCount + 1 end
    streamWriteInt32(streamId, activeTaskCount)

    for _, task in pairs(g_currentMission.taskList.activeTasks) do
        streamWriteString(streamId, task.id)
        streamWriteString(streamId, task.groupId)
    end
end

function InitialClientStateEvent:readStream(streamId, connection)
    local groupCount = streamReadInt32(streamId)
    for i = 1, groupCount do
        local group = TaskGroup.new()
        group:readStream(streamId, connection)
        g_currentMission.taskList.taskGroups[group.id] = group
    end

    local activeTaskCount = streamReadInt32(streamId)
    for i = 1, activeTaskCount do
        local taskId = streamReadString(streamId)
        local groupId = streamReadString(streamId)
        g_currentMission.taskList:addActiveTask(groupId, taskId)
    end

    self:run(connection)
end

function InitialClientStateEvent:run(connection)
    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end
