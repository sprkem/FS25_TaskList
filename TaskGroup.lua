TaskGroup = {}
local Group_mt = Class(TaskGroup)

TaskGroup.MAX_NAME_LENGTH = 30
TaskGroup.GROUP_TYPE = {
    Standard = 1,
    Template = 2,
    TemplateInstance = 3
}
TaskGroup.GROUP_TYPE_STRINGS = {
    [TaskGroup.GROUP_TYPE.Standard] = "ui_group_type_standard",
    [TaskGroup.GROUP_TYPE.Template] = "ui_group_type_template",
    [TaskGroup.GROUP_TYPE.TemplateInstance] = "ui_group_type_template_instance"
}

function TaskGroup.new(customMt)
    local self = {}

    setmetatable(self, customMt or Group_mt)

    self.id = g_currentMission.taskList:generateId()
    self.farmId = g_currentMission.taskList:getCurrentFarmId()
    self.name = ""
    self.effortMultiplier = 1
    self.type = TaskGroup.GROUP_TYPE.Standard
    self.templateGroupId = ""
    self.tasks = {}
    return self
end

function TaskGroup:copyValuesFromGroup(sourceGroup, includeId)
    self.farmId = sourceGroup.farmId
    self.name = sourceGroup.name
    self.type = sourceGroup.type
    self.templateGroupId = sourceGroup.templateGroupId
    self.effortMultiplier = sourceGroup.effortMultiplier

    for _, task in pairs(sourceGroup.tasks) do
        local newTask = Task.new()
        newTask:copyValuesFromTask(task, false)
        self.tasks[newTask.id] = newTask
    end

    if includeId then
        self.id = sourceGroup.id
    end
end

function TaskGroup:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.type)
    streamWriteString(streamId, self.templateGroupId)
    streamWriteString(streamId, self.name)
    streamWriteInt32(streamId, self.effortMultiplier)


    local taskCount = 0
    for _ in pairs(self.tasks) do taskCount = taskCount + 1 end
    streamWriteInt32(streamId, taskCount)
    
    for _, task in pairs(self.tasks) do
        task:writeStream(streamId, connection)
    end
end

function TaskGroup:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self.farmId = streamReadInt32(streamId)
    self.type = streamReadInt32(streamId)
    self.templateGroupId = streamReadString(streamId)
    self.name = streamReadString(streamId)
    self.effortMultiplier = streamReadInt32(streamId)

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
    setXMLInt(xmlFile, key .. "#type", self.type)
    setXMLString(xmlFile, key .. "#templateGroupId", self.templateGroupId)
    setXMLInt(xmlFile, key .. "#effortMultiplier", self.effortMultiplier)

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
    self.type = getXMLInt(xmlFile, key .. "#type") or TaskGroup.GROUP_TYPE.Standard
    self.templateGroupId = getXMLString(xmlFile, key .. "#templateGroupId") or ""
    self.effortMultiplier = getXMLInt(xmlFile, key .. "#effortMultiplier") or 1

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
