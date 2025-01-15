--
-- FS25 - TodoList
--
-- @Author: Ozz
-- @Date: 24.11.2024
-- @Version: 1.0.0.0
--
-- Changelog:
--  v1.0.0.0 (26.02.2022):
--  - Initial Release
--
math.randomseed(g_time or os.clock())

TodoList = {}
TodoList.dir = g_currentModDirectory
TodoList.modName = g_currentModName

source(TodoList.dir .. "TaskListUtils.lua")
source(TodoList.dir .. "TaskGroup.lua")
source(TodoList.dir .. "Task.lua")
source(TodoList.dir .. "gui/InGameMenuTodoList.lua")
source(TodoList.dir .. "gui/ManageGroupsFrame.lua")
source(TodoList.dir .. "gui/ManageTasksFrame.lua")
source(TodoList.dir .. "events/InitialClientState.lua")
source(TodoList.dir .. "events/NewTaskGroupEvent.lua")
source(TodoList.dir .. "events/DeleteGroupEvent.lua")
source(TodoList.dir .. "events/NewTaskGroupEvent.lua")
source(TodoList.dir .. "events/CompleteTaskEvent.lua")
source(TodoList.dir .. "events/DeleteTaskEvent.lua")
source(TodoList.dir .. "events/NewTaskEvent.lua")

function TodoList:loadMap()
    MessageType.ACTIVE_TASKS_UPDATED = nextMessageTypeId()
    MessageType.TASK_GROUPS_UPDATED = nextMessageTypeId()

    g_gui:loadProfiles(TodoList.dir .. "gui/guiProfiles.xml")

    local guiTodoList = InGameMenuTodoList.new(g_i18n)
    g_gui:loadGui(TodoList.dir .. "gui/InGameMenuTodoList.xml", "inGameMenuTodoList", guiTodoList, true)

    local manageGroupsFrame = ManageGroupsFrame.new(g_i18n)
    g_gui:loadGui(TodoList.dir .. "gui/ManageGroupsFrame.xml", "manageGroupsFrame", manageGroupsFrame)

    local manageTasksFrame = ManageTasksFrame.new(g_i18n)
    g_gui:loadGui(TodoList.dir .. "gui/ManageTasksFrame.xml", "manageTasksFrame", manageTasksFrame)

    TodoList.fixInGameMenu(guiTodoList, "inGameMenuTodoList", { 0, 0, 1024, 1024 }, 2,
        TodoList:makeIsTodoListCheckEnabledPredicate())

    g_currentMission.todoList = self
    self.taskGroups = {}
    self.activeTasks = {}
    self.currentPeriod = math.floor(g_currentMission.environment.currentPeriod)
    -- self.currentPeriod = 5 -- TODO = replace

    -- -- TODO - remove below synthetic data
    -- local group1 = TaskGroup.new()
    -- group1.farmId = 1
    -- group1.name = "field 1"
    -- self.taskGroups[group1.id] = group1

    -- local task1 = Task.new()
    -- task1.detail = "Harvest"
    -- task1.priority = 1
    -- task1.period = 6
    -- task1.shouldRecur = true
    -- task1.shouldRecurMode = Task.SHOULD_REPEAT_MODE.MONTHLY
    -- self.taskGroups[group1.id].tasks[task1.id] = task1

    -- local task2 = Task.new()
    -- task2.detail = "Mulch"
    -- task2.priority = 1
    -- task2.period = 6
    -- task2.shouldRecur = true
    -- task2.shouldRecurMode = Task.SHOULD_REPEAT_MODE.MONTHLY
    -- self.taskGroups[group1.id].tasks[task2.id] = task2

    -- local group2 = TaskGroup.new()
    -- group2.farmId = 1
    -- group2.name = "field 2"
    -- self.taskGroups[group2.id] = group2

    -- local task3 = Task.new()
    -- task3.detail = "Harvest"
    -- task3.priority = 1
    -- task3.period = 6
    -- task3.shouldRecur = true
    -- task3.shouldRecurMode = Task.SHOULD_REPEAT_MODE.MONTHLY
    -- self.taskGroups[group2.id].tasks[task3.id] = task3

    -- local task4 = Task.new()
    -- task4.detail = "Cultivate"
    -- task4.priority = 1
    -- task4.period = 6
    -- task4.shouldRecur = true
    -- task4.shouldRecurMode = Task.SHOULD_REPEAT_MODE.DAILY
    -- self.taskGroups[group2.id].tasks[task4.id] = task4

    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, TodoList.saveToXmlFile)
    self:loadFromXMLFile()

    guiTodoList:initialize()
end

function TodoList:makeIsTodoListCheckEnabledPredicate()
    return function() return true end
end

function TodoList:saveToXmlFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory .. "/"
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(),
            g_currentMission.missionInfo.savegameIndex .. "/")
    end

    local key = "tasklist";
    local xmlFile = createXMLFile(key, savegameFolderPath .. "tasklist.xml", key);

    local i = 0
    for _, group in pairs(g_currentMission.todoList.taskGroups) do
        local groupKey = string.format("%s.taskGroups.group(%d)", key, i)
        group:saveToXmlFile(xmlFile, groupKey)
        i = i + 1
    end
    
    local j = 0
    for _, activeTask in pairs(g_currentMission.todoList.activeTasks) do
        local activeTaskKey = string.format("%s.activeTasks.tasks(%d)", key, j)
        setXMLString(xmlFile, activeTaskKey .. "#id", activeTask.id)
        setXMLString(xmlFile, activeTaskKey .. "#groupId", activeTask.groupId)
        j = j + 1
    end

    saveXMLFile(xmlFile);
    delete(xmlFile);
end

function TodoList:loadFromXMLFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
    end
    savegameFolderPath = savegameFolderPath .. "/"
    local key = "tasklist"

    if fileExists(savegameFolderPath .. "tasklist.xml") then
        local xmlFile = loadXMLFile(key, savegameFolderPath .. "tasklist.xml");

        local i = 0
        while true do
            local groupKey = string.format(key .. ".taskGroups.group(%d)", i)
            print("Loading groupkey " .. groupKey)
            if not hasXMLProperty(xmlFile, groupKey) then
                break
            end

            local group = TaskGroup.new()
            group:loadFromXMLFile(xmlFile, groupKey)
            g_currentMission.todoList.taskGroups[group.id] = group
            i = i + 1
        end

        local j = 0
        while true do
            local activeTaskKey = string.format("%s.activeTasks.tasks(%d)", key, j)
            print("Loading activeTaskKey " .. activeTaskKey)
            if not hasXMLProperty(xmlFile, activeTaskKey) then
                break
            end

            local taskId = getXMLString(xmlFile, activeTaskKey .. "#id")
            local groupId = getXMLString(xmlFile, activeTaskKey .. "#groupId")
            g_currentMission.todoList:addActiveTask(groupId, taskId)
            j = j + 1
        end


        delete(xmlFile)
    end
end

-- from Courseplay
function TodoList.fixInGameMenu(frame, pageName, uvs, position, predicateFunc)
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local targetPosition = 0

    -- remove all to avoid warnings
    for k, v in pairs({ pageName }) do
        inGameMenu.controlIDs[v] = nil
    end

    for i = 1, #inGameMenu.pagingElement.elements do
        local child = inGameMenu.pagingElement.elements[i]
        if child == inGameMenu["pageSettings"] then
            targetPosition = i;
            break
        end
    end

    if targetPosition == 0 then
        targetPosition = position
    end

    inGameMenu[pageName] = frame
    inGameMenu.pagingElement:addElement(inGameMenu[pageName])

    inGameMenu:exposeControlsAsFields(pageName)

    for i = 1, #inGameMenu.pagingElement.elements do
        local child = inGameMenu.pagingElement.elements[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.elements, i)
            table.insert(inGameMenu.pagingElement.elements, targetPosition, child)
            break
        end
    end

    for i = 1, #inGameMenu.pagingElement.pages do
        local child = inGameMenu.pagingElement.pages[i]
        if child.element == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.pages, i)
            table.insert(inGameMenu.pagingElement.pages, targetPosition, child)
            break
        end
    end

    inGameMenu.pagingElement:updateAbsolutePosition()
    inGameMenu.pagingElement:updatePageMapping()

    inGameMenu:registerPage(inGameMenu[pageName], position, predicateFunc)
    local iconFileName = Utils.getFilename('images/menuIcon.dds', TodoList.dir)
    inGameMenu:addPageTab(inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))

    for i = 1, #inGameMenu.pageFrames do
        local child = inGameMenu.pageFrames[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pageFrames, i)
            table.insert(inGameMenu.pageFrames, targetPosition, child)
            break
        end
    end

    inGameMenu:rebuildTabList()
end

function TodoList:hourChanged()
    print("Hour changed received")
    local period = math.floor(g_currentMission.environment.currentPeriod)
    if period ~= g_currentMission.todoList.currentPeriod then
        g_currentMission.todoList:onPeriodChanged()
    end
end

function TodoList:onPeriodChanged()
    print("Month changed, updating tasks")
    for _, group in pairs(self.taskGroups) do
        self:addGroupTasksForCurrentPeriod(group)
    end
    g_currentMission.todoList.currentPeriod = math.floor(g_currentMission.environment.currentPeriod)
end

function TodoList:addGroupTasksForCurrentPeriod(group)
    local currentPeriod = math.floor(g_currentMission.environment.currentPeriod)
    local additions = false
    for _, task in pairs(group.tasks) do
        if task.period == currentPeriod then
            self:addActiveTask(group.id, task.id)
            additions = true
        end
    end
    if additions == true then
        g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    end
end

function TodoList:addActiveTask(groupId, taskId)
    local group = self.taskGroups[groupId]
    local task = group.tasks[taskId]
    local taskCopy = TaskListUtils.deepcopy(task)
    taskCopy.groupName = group.name
    taskCopy.groupId = group.id

    self.activeTasks[taskCopy.id] = taskCopy
    -- Expect caller to raise ACTIVE_TASKS_UPDATED as this is called repeatedly
end

function TodoList:getActiveTasksForCurrentFarm()
    local result = {}
    for _, task in pairs(self.activeTasks) do
        if task.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            local taskCopy = TaskListUtils.deepcopy(task)
            table.insert(result, taskCopy)
        end
    end
    return result
end

function TodoList:getTasksForPeriodForCurrentFarm(period)
    local result = {}
    for _, group in pairs(self.taskGroups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            for _, task in pairs(group.tasks) do
                if task.period == period then
                    local taskCopy = TaskListUtils.deepcopy(task)
                    taskCopy.groupName = group.name
                    table.insert(result, taskCopy)
                end
            end
        end
    end
    return result
end

function TodoList:completeTask(taskId)
    local task = self.activeTasks[taskId]
    if task == nil then
        InfoDialog.show(g_i18n:getText("ui_task_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(CompleteTaskEvent.new(taskId))
end

function TodoList:deleteTask(groupId, taskId)
    local group = self.taskGroups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    local task = group.tasks[taskId]
    if task == nil then
        InfoDialog.show(g_i18n:getText("ui_task_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(DeleteTaskEvent.new(groupId, taskId))
end

function TodoList:addTask(groupId, task)
    local group = self.taskGroups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(NewTaskEvent.new(groupId, task))
end

function TodoList:deleteGroup(groupId)
    local group = self.taskGroups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(DeleteGroupEvent.new(groupId))
end

function TodoList:addGroupForCurrentFarm(name)
    local group = TaskGroup.new()
    group.name = name
    g_client:getServerConnection():sendEvent(NewTaskGroupEvent.new(group))
end

function TodoList:copyGroupForCurrentFarm(newName, groupToCopyId)
    -- Sanity check the group exists
    local sourceGroup = self.taskGroups[groupToCopyId]
    if sourceGroup == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    local group = TaskGroup.new()
    group.name = newName
    group:copyTasksFromGroup(sourceGroup)

    g_client:getServerConnection():sendEvent(NewTaskGroupEvent.new(group))
end

function TodoList:getGroupListForCurrentFarm()
    local currentFarmId = self:getCurrentFarmId()
    local result = {}
    for _, group in pairs(self.taskGroups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            table.insert(result, {
                id = group.id,
                name = group.name
            })
        end
    end
    return result
end

function TodoList:getGroupById(groupId, showInfoIfNotFound)
    -- Returns a copy of the group but tasks are indexed sequentially for table rendering
    local group = self.taskGroups[groupId]
    if group == nil then
        if showInfoIfNotFound == true then
            InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        end
        return nil
    end

    local groupCopy = TaskListUtils.deepcopy(group)
    groupCopy.tasks = {}
    for _, task in pairs(group.tasks) do
        local taskCopy = TaskListUtils.deepcopy(task)
        table.insert(groupCopy.tasks, taskCopy)
    end

    return groupCopy
end

function TodoList:groupExistsForCurrentFarm(name)
    local currentFarmId = self:getCurrentFarmId()
    for _, group in pairs(self.taskGroups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            if group.name == name then
                return true
            end
        end
    end
    return false
end

function TodoList:getCurrentFarmId()
    local currentFarmId = -1
    local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if farm ~= nil then
        return farm.farmId
    end
    return currentFarmId -- Not sure can happen!
end

function TodoList:generateId()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, TodoList.hourChanged)
addModEventListener(TodoList)

function TodoList:sendInitialClientState(connection, user, farm)
    connection:sendEvent(InitialClientStateEvent.new())
end

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
    TodoList.sendInitialClientState)
