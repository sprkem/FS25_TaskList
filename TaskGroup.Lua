TaskGroup = {}
local Group_mt = Class(TaskGroup)

TaskGroup.MAX_NAME_LENGTH = 30

function TaskGroup.new(customMt)
    local self = {}

    setmetatable(self, customMt or Group_mt)

    self.id = g_currentMission.todoList:generateId()
    self.farmId = g_currentMission.todoList:getCurrentFarmId()
    self.name = ""
    self.tasks = {}
    return self
end

function TaskGroup:copyTasksFromGroup(sourceGroup)
    for _, task in pairs(sourceGroup.tasks) do
        local newTask = Task.new()
        newTask:copyValuesFromTask(task)
        self.tasks[newTask.id] = newTask
    end
end

function TaskGroup:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteInt32(streamId, self.farmId)
    streamWriteString(streamId, self.name)

    local taskCount = 0
    for _ in pairs(self.tasks) do taskCount = taskCount + 1 end
    streamWriteInt32(streamId, taskCount)

    -- For each task in the group
    for _, task in pairs(self.tasks) do
        task:writeStream(streamId, connection)
    end
end

function TaskGroup:readStream(streamId, connection)
    self.id = streamReadSring(streamId)
    self.farmId = streamReadInt32(streamId)
    self.name = streamReadSring(streamId)

    local taskCount = streamReadInt32(streamId)
    for j = 1, taskCount do
        local task = Task.new()
        task:readStream(streamId, connection)
        self.tasks[task.id] = task
    end
end

function TaskGroup:saveToXmlFile(xmlFile, key)
    setXMLString(xmlFile, key .. "#id", self.id)
    setXMLString(xmlFile, key .. "#name", self.name)
    setXMLInt(xmlFile, key .. "#farmId", self.farmId)
    
    local i = 0
    for _, task in pairs(self.tasks) do
        local taskKey = string.format("%s.tasks.task(%d)", key, i)
        task:saveToXmlFile(xmlFile, taskKey)
        i = i + 1
    end
end

function TaskGroup:loadFromXMLFile(xmlFile, key)
    self.id = getXMLString(xmlFile, key .. "#id")
    self.name = getXMLString(xmlFile, key .. "#name")
    self.farmId = getXMLInt(xmlFile, key .. "#farmId")

    local i = 0
    while true do
        local taskKey = string.format("%s.tasks.task(%d)", key, i)
        if not hasXMLProperty(xmlFile, taskKey) then
            break
        end
        local task = Task.new()
        task:loadFromXMLFile(xmlFile, taskKey)
        self.tasks[task.id] = task
        i = i + 1
    end
end
