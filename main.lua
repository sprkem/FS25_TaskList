--
-- FS25 - TaskList
--
-- @Author: Ozz
-- @Date: 24.11.2024
-- @Version: 1.0.0.0
--
-- Changelog:
--  v1.0.0.0 (16.01.2024):
--  - Initial Release
--
math.randomseed(g_time or os.clock())

TaskList = {}
TaskList.dir = g_currentModDirectory
TaskList.modName = g_currentModName

source(TaskList.dir .. "TaskListUtils.lua")
source(TaskList.dir .. "TaskGroup.lua")
source(TaskList.dir .. "Task.lua")
source(TaskList.dir .. "gui/MenuTaskList.lua")
source(TaskList.dir .. "gui/ManageGroupsFrame.lua")
source(TaskList.dir .. "gui/ManageTasksFrame.lua")
source(TaskList.dir .. "events/InitialClientState.lua")
source(TaskList.dir .. "events/NewTaskGroupEvent.lua")
source(TaskList.dir .. "events/DeleteGroupEvent.lua")
source(TaskList.dir .. "events/NewTaskGroupEvent.lua")
source(TaskList.dir .. "events/CompleteTaskEvent.lua")
source(TaskList.dir .. "events/DeleteTaskEvent.lua")
source(TaskList.dir .. "events/NewTaskEvent.lua")

function TaskList:loadMap()
    MessageType.ACTIVE_TASKS_UPDATED = nextMessageTypeId()
    MessageType.TASK_GROUPS_UPDATED = nextMessageTypeId()

    g_gui:loadProfiles(TaskList.dir .. "gui/guiProfiles.xml")

    local guiTaskList = MenuTaskList.new(g_i18n)
    g_gui:loadGui(TaskList.dir .. "gui/MenuTaskList.xml", "menuTaskList", guiTaskList, true)

    local manageGroupsFrame = ManageGroupsFrame.new(g_i18n)
    g_gui:loadGui(TaskList.dir .. "gui/ManageGroupsFrame.xml", "manageGroupsFrame", manageGroupsFrame)

    local manageTasksFrame = ManageTasksFrame.new(g_i18n)
    g_gui:loadGui(TaskList.dir .. "gui/ManageTasksFrame.xml", "manageTasksFrame", manageTasksFrame)

    TaskList.fixInGameMenu(guiTaskList, "menuTaskList", { 0, 0, 1024, 1024 }, 2,
        TaskList:makeIsTaskListCheckEnabledPredicate())

    g_currentMission.taskList = self
    self.taskGroups = {}
    self.activeTasks = {}
    self.currentPeriod = math.floor(g_currentMission.environment.currentPeriod)

    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, TaskList.saveToXmlFile)
    self:loadFromXMLFile()

    guiTaskList:initialize()
end

function TaskList:makeIsTaskListCheckEnabledPredicate()
    return function() return true end
end

function TaskList:saveToXmlFile()
    if (not g_currentMission:getIsServer()) then return end

    local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory .. "/"
    if savegameFolderPath == nil then
        savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(),
            g_currentMission.missionInfo.savegameIndex .. "/")
    end

    local key = "tasklist";
    local xmlFile = createXMLFile(key, savegameFolderPath .. "tasklist.xml", key);

    local i = 0
    for _, group in pairs(g_currentMission.taskList.taskGroups) do
        local groupKey = string.format("%s.taskGroups.group(%d)", key, i)
        group:saveToXmlFile(xmlFile, groupKey)
        i = i + 1
    end
    
    local j = 0
    for _, activeTask in pairs(g_currentMission.taskList.activeTasks) do
        local activeTaskKey = string.format("%s.activeTasks.tasks(%d)", key, j)
        setXMLString(xmlFile, activeTaskKey .. "#id", activeTask.id)
        setXMLString(xmlFile, activeTaskKey .. "#groupId", activeTask.groupId)
        j = j + 1
    end

    saveXMLFile(xmlFile);
    delete(xmlFile);
end

function TaskList:loadFromXMLFile()
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
            if not hasXMLProperty(xmlFile, groupKey) then
                break
            end

            local group = TaskGroup.new()
            group:loadFromXMLFile(xmlFile, groupKey)
            g_currentMission.taskList.taskGroups[group.id] = group
            i = i + 1
        end

        local j = 0
        while true do
            local activeTaskKey = string.format("%s.activeTasks.tasks(%d)", key, j)
            if not hasXMLProperty(xmlFile, activeTaskKey) then
                break
            end

            local taskId = getXMLString(xmlFile, activeTaskKey .. "#id")
            local groupId = getXMLString(xmlFile, activeTaskKey .. "#groupId")
            g_currentMission.taskList:addActiveTask(groupId, taskId)
            j = j + 1
        end


        delete(xmlFile)
    end
end

-- from Courseplay
function TaskList.fixInGameMenu(frame, pageName, uvs, position, predicateFunc)
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
    local iconFileName = Utils.getFilename('images/menuIcon.dds', TaskList.dir)
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

function TaskList:hourChanged()
    local period = math.floor(g_currentMission.environment.currentPeriod)
    if period ~= g_currentMission.taskList.currentPeriod then
        g_currentMission.taskList:onPeriodChanged()
    end
end

function TaskList:onPeriodChanged()
    for _, group in pairs(self.taskGroups) do
        self:addGroupTasksForCurrentPeriod(group)
    end
    g_currentMission.taskList.currentPeriod = math.floor(g_currentMission.environment.currentPeriod)
end

function TaskList:addGroupTasksForCurrentPeriod(group)
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

function TaskList:addActiveTask(groupId, taskId)
    local group = self.taskGroups[groupId]
    local task = group.tasks[taskId]
    local taskCopy = TaskListUtils.deepcopy(task)
    taskCopy.groupName = group.name
    taskCopy.groupId = group.id

    self.activeTasks[taskCopy.id] = taskCopy
    -- Expect caller to raise ACTIVE_TASKS_UPDATED as this is called repeatedly
end

function TaskList:getActiveTasksForCurrentFarm()
    local result = {}
    for _, task in pairs(self.activeTasks) do
        if task.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            local taskCopy = TaskListUtils.deepcopy(task)
            table.insert(result, taskCopy)
        end
    end
    return result
end

function TaskList:getTasksForPeriodForCurrentFarm(period)
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

function TaskList:completeTask(groupId, taskId)
    local task = self.activeTasks[taskId]
    if task == nil then
        InfoDialog.show(g_i18n:getText("ui_task_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(CompleteTaskEvent.new(groupId, taskId))
end

function TaskList:deleteTask(groupId, taskId)
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

function TaskList:addTask(groupId, task)
    local group = self.taskGroups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(NewTaskEvent.new(groupId, task))
end

function TaskList:deleteGroup(groupId)
    local group = self.taskGroups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(DeleteGroupEvent.new(groupId))
end

function TaskList:addGroupForCurrentFarm(name)
    local group = TaskGroup.new()
    group.name = name
    g_client:getServerConnection():sendEvent(NewTaskGroupEvent.new(group))
end

function TaskList:copyGroupForCurrentFarm(newName, groupToCopyId)
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

function TaskList:getGroupListForCurrentFarm()
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

function TaskList:getGroupById(groupId, showInfoIfNotFound)
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

function TaskList:groupExistsForCurrentFarm(name)
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

function TaskList:getCurrentFarmId()
    local currentFarmId = -1
    local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if farm ~= nil then
        return farm.farmId
    end
    return currentFarmId -- Not sure can happen!
end

function TaskList:generateId()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, TaskList.hourChanged)
addModEventListener(TaskList)

function TaskList:sendInitialClientState(connection, user, farm)
    connection:sendEvent(InitialClientStateEvent.new())
end

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
    TaskList.sendInitialClientState)
