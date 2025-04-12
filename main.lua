--
-- FS25 - TaskList
--
-- @Author: Ozz
-- @Date: 24.11.2024
-- @Version: 1.0.0.0
--
-- Changelog:
--  1.0.0 (16.01.2024): Initial Release
--  1.0.1 (03/03/2025): Multiplayer fixes
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
source(TaskList.dir .. "gui/tableRenderers/MonthlyTaskRenderer.lua")
source(TaskList.dir .. "events/InitialClientStateEvent.lua")
source(TaskList.dir .. "events/NewTaskGroupEvent.lua")
source(TaskList.dir .. "events/EditTaskGroupEvent.lua")
source(TaskList.dir .. "events/DeleteGroupEvent.lua")
source(TaskList.dir .. "events/NewTaskGroupEvent.lua")
source(TaskList.dir .. "events/CompleteTaskEvent.lua")
source(TaskList.dir .. "events/DeleteTaskEvent.lua")
source(TaskList.dir .. "events/EditTaskEvent.lua")
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

    TaskList.addIngameMenuPage(guiTaskList, "menuTaskList", { 0, 0, 1024, 1024 },
        TaskList:makeIsTaskListCheckEnabledPredicate(), "pageSettings")

    g_currentMission.taskList = self
    self.taskGroups = {}
    self.activeTasks = {}
    self.templateTasksAdded = {}
    self.currentPeriod = g_currentMission.environment.currentPeriod
    self.currentDay = g_currentMission.environment.currentDay

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
        setXMLInt(xmlFile, activeTaskKey .. "#createdMarker", activeTask.createdMarker)
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
            local task = g_currentMission.taskList:addActiveTask(groupId, taskId)
            task.createdMarker = getXMLInt(xmlFile, activeTaskKey .. "#createdMarker")
            j = j + 1
        end


        delete(xmlFile)
    end
end

-- from Courseplay
function TaskList.addIngameMenuPage(frame, pageName, uvs, predicateFunc, insertAfter)
    local targetPosition = 0

    -- remove all to avoid warnings
    for k, v in pairs({ pageName }) do
        g_inGameMenu.controlIDs[v] = nil
    end

    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[insertAfter] then
            targetPosition = i + 1;
            break
        end
    end

    g_inGameMenu[pageName] = frame
    g_inGameMenu.pagingElement:addElement(g_inGameMenu[pageName])

    g_inGameMenu:exposeControlsAsFields(pageName)

    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.elements, i)
            table.insert(g_inGameMenu.pagingElement.elements, targetPosition, child)
            break
        end
    end

    for i = 1, #g_inGameMenu.pagingElement.pages do
        local child = g_inGameMenu.pagingElement.pages[i]
        if child.element == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pagingElement.pages, i)
            table.insert(g_inGameMenu.pagingElement.pages, targetPosition, child)
            break
        end
    end

    g_inGameMenu.pagingElement:updateAbsolutePosition()
    g_inGameMenu.pagingElement:updatePageMapping()

    g_inGameMenu:registerPage(g_inGameMenu[pageName], nil, predicateFunc)

    local iconFileName = Utils.getFilename('images/menuIcon.dds', TaskList.dir)
    g_inGameMenu:addPageTab(g_inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))

    for i = 1, #g_inGameMenu.pageFrames do
        local child = g_inGameMenu.pageFrames[i]
        if child == g_inGameMenu[pageName] then
            table.remove(g_inGameMenu.pageFrames, i)
            table.insert(g_inGameMenu.pageFrames, targetPosition, child)
            break
        end
    end

    g_inGameMenu:rebuildTabList()
end

function TaskList:hourChanged()
    local period = g_currentMission.environment.currentPeriod
    if period ~= g_currentMission.taskList.currentPeriod then
        g_currentMission.taskList:onPeriodChanged()
        return
    end
    local day = g_currentMission.environment.currentDay
    if day ~= g_currentMission.taskList.currentDay then
        g_currentMission.taskList:onDayChanged()
        return
    end
end

function TaskList:playerFarmChanged()
    g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
    g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
end

function TaskList:onPeriodChanged()
    for _, group in pairs(self.taskGroups) do
        self:addGroupTasksForCurrentPeriod(group)
        self:addDailyTasks(group)
    end
    g_currentMission.taskList.currentPeriod = g_currentMission.environment.currentPeriod
    g_currentMission.taskList.currentDay = g_currentMission.environment.currentDay
    self:updateTemplateAddedTasks()
end

function TaskList:onDayChanged()
    for _, group in pairs(self.taskGroups) do
        self:addDailyTasks(group)
    end
    g_currentMission.taskList.currentDay = g_currentMission.environment.currentDay
    self:updateTemplateAddedTasks()
end

function TaskList:addGroupTasksForCurrentPeriod(group)
    if group.type == TaskGroup.GROUP_TYPE.Template then return end
    local additions = false

    local tasks = group.tasks
    if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
        tasks = self.taskGroups[group.templateGroupId].tasks
    end

    for _, task in pairs(tasks) do
        if task.recurMode == Task.RECUR_MODE.NONE or task.recurMode == Task.RECUR_MODE.MONTHLY or task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
            local didAdd = self:checkAndAddActiveTaskIfDue(group, task)
            if didAdd then additions = true end
        end
    end
    if additions == true then
        g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    end
end

function TaskList:addDailyTasks(group)
    if group.type == TaskGroup.GROUP_TYPE.Template then return end
    local additions = false

    local tasks = group.tasks
    if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
        tasks = self.taskGroups[group.templateGroupId].tasks
    end

    for _, task in pairs(tasks) do
        if task.recurMode == Task.RECUR_MODE.DAILY or task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
            local didAdd = self:checkAndAddActiveTaskIfDue(group, task)
            if didAdd then additions = true end
        end
    end
    if additions == true then
        g_messageCenter:publish(MessageType.ACTIVE_TASKS_UPDATED)
    end
end

function TaskList:checkAndAddActiveTaskIfDue(group, task)
    local currentDay = g_currentMission.environment.currentDay
    local currentPeriod = g_currentMission.environment.currentPeriod
    local shouldAdd = false
    if task.recurMode == Task.RECUR_MODE.DAILY then
        shouldAdd = true
    elseif task.recurMode == Task.RECUR_MODE.NONE and task.period == currentPeriod then
        shouldAdd = true
    elseif task.recurMode == Task.RECUR_MODE.MONTHLY and task.period == currentPeriod then
        shouldAdd = true
    elseif task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS and task.nextN == currentDay then
        shouldAdd = true
    elseif task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS and task.nextN == currentPeriod then
        shouldAdd = true
    end

    if shouldAdd then
        self:addActiveTask(group.id, task.id)
        if task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS or task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
            if group.type == TaskGroup.GROUP_TYPE.Standard then
                task.nextN = task.nextN + task.n
                if task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS and task.nextN > 12 then
                    task.nextN = task.nextN - 12
                end
            elseif group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
                if self.templateTasksAdded[group.templateGroupId] == nil then
                    self.templateTasksAdded[group.templateGroupId] = {}
                end
                self.templateTasksAdded[group.templateGroupId][task.id] = true
            end
        end
        return true
    end

    return false
end

function TaskList:updateTemplateAddedTasks()
    for groupId, tasks in pairs(self.templateTasksAdded) do
        for taskId, _ in pairs(tasks) do
            local task = self.taskGroups[groupId].tasks[taskId]
            task.nextN = task.nextN + task.n
            if task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS and task.nextN > 12 then
                task.nextN = task.nextN - 12
            end
        end
    end
    self.templateTasksAdded = {}
end

function TaskList:addActiveTask(groupId, taskId)
    local group = self.taskGroups[groupId]

    local task = group.tasks[taskId]
    if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
        task = self.taskGroups[group.templateGroupId].tasks[taskId]
    end

    local taskCopy = TaskListUtils.deepcopy(task)
    taskCopy.groupName = group.name
    taskCopy.groupId = group.id

    if task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
        taskCopy.createdMarker = g_currentMission.environment.currentDay
    else
        taskCopy.createdMarker = g_currentMission.environment.currentPeriod
    end

    local key = taskCopy.groupId .. "_" .. taskCopy.id
    self.activeTasks[key] = taskCopy
    -- Expect caller to raise ACTIVE_TASKS_UPDATED as this is called repeatedly
    return taskCopy
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

function TaskList:getTasksForNextYear()
    local result = {}
    for i = 1, 12 do
        result[i] = {}
    end
    for _, group in pairs(self.taskGroups) do
        local tasks = group.tasks
        if group.type == TaskGroup.GROUP_TYPE.TemplateInstance then
            tasks = self.taskGroups[group.templateGroupId].tasks
        elseif group.type == TaskGroup.GROUP_TYPE.Template then
            tasks = {}
        end

        for _, task in pairs(tasks) do
            local effort = task.effort * group.effortMultiplier
            if task.recurMode == Task.RECUR_MODE.MONTHLY or task.recurMode == Task.RECUR_MODE.NONE then
                local month = TaskListUtils.convertPeriodToMonthNumber(task.period)
                table.insert(result[month],
                    { groupId = group.id, taskId = task.id, effort = effort, priority = task.priority })
            elseif task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
                local currentMonth = TaskListUtils.convertPeriodToMonthNumber(g_currentMission.environment.currentPeriod)
                local firstMonth = TaskListUtils.convertPeriodToMonthNumber(task.nextN)
                local count = firstMonth - currentMonth
                if count < 0 then
                    count = count + 12
                end
                table.insert(result[firstMonth],
                    { groupId = group.id, taskId = task.id, effort = effort, priority = task.priority })

                local lastAdded = firstMonth
                while true do
                    count = count + task.n
                    if count >= 12 then
                        break
                    end

                    local next = lastAdded + task.n
                    if next > 12 then
                        next = next - 12
                    end

                    table.insert(result[next],
                        { groupId = group.id, taskId = task.id, effort = effort, priority = task.priority })
                    lastAdded = next
                end
            elseif task.recurMode == Task.RECUR_MODE.DAILY or task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
                local startMonth = TaskListUtils.convertPeriodToMonthNumber(g_currentMission.environment.currentPeriod)
                local currentMonth = startMonth
                local daysPerPeriod = g_currentMission.environment.daysPerPeriod
                local plannedDaysPerPeriod = g_currentMission.environment.plannedDaysPerPeriod
                local currentDayInPeriod = g_currentMission.environment.currentDayInPeriod
                local currentDay = g_currentMission.environment.currentDay
                local startSeason = g_currentMission.environment:getSeasonAtDay(currentDay)
                local seasonChanged = false

                local increment = 1
                local firstDay = currentDay
                if task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
                    increment = task.n
                    firstDay = task.nextN
                end

                if currentDayInPeriod + increment > daysPerPeriod then
                    currentMonth = currentMonth + 1
                    currentDayInPeriod = daysPerPeriod - (currentDayInPeriod + increment)
                    if currentMonth > 12 then
                        currentMonth = currentMonth - 12
                    end
                end

                table.insert(result[currentMonth],
                    { groupId = group.id, taskId = task.id, effort = effort, priority = task.priority })
                local lastAdded = firstDay
                while true do
                    if not seasonChanged and startSeason ~= g_currentMission.environment:getSeasonAtDay(lastAdded) then
                        daysPerPeriod = plannedDaysPerPeriod
                        seasonChanged = true
                    end

                    if currentDayInPeriod + increment > daysPerPeriod then
                        currentMonth = currentMonth + 1
                        currentDayInPeriod = daysPerPeriod - (currentDayInPeriod + increment)
                        if currentMonth > 12 then
                            currentMonth = currentMonth - 12
                        end
                    end

                    if currentMonth == startMonth then
                        break
                    end

                    table.insert(result[currentMonth],
                        { groupId = group.id, taskId = task.id, effort = effort, priority = task.priority })
                    lastAdded = lastAdded + increment
                end
            end
        end
    end
    -- Sort each months tasks by priority
    for i = 1, 12 do
        table.sort(result[i], function(k1, k2) return k1.priority < k2.priority end)
    end

    return result
end

function TaskList:completeTask(groupId, taskId)
    local key = groupId .. "_" .. taskId
    local task = self.activeTasks[key]

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

function TaskList:addTask(groupId, task, isEdit)
    if self.taskGroups[groupId] == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    if isEdit then
        g_client:getServerConnection():sendEvent(EditTaskEvent.new(groupId, task))
    else
        g_client:getServerConnection():sendEvent(NewTaskEvent.new(groupId, task))
    end
end

function TaskList:deleteGroup(groupId)
    local group = self.taskGroups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    if group.type == TaskGroup.GROUP_TYPE.Template then
        for _, tg in pairs(self.taskGroups) do
            if tg.type == TaskGroup.GROUP_TYPE.TemplateInstance and tg.templateGroupId == group.id then
                g_client:getServerConnection():sendEvent(DeleteGroupEvent.new(tg.id))
            end
        end
    end

    g_client:getServerConnection():sendEvent(DeleteGroupEvent.new(groupId))
end

function TaskList:addGroupForCurrentFarm(group)
    g_client:getServerConnection():sendEvent(NewTaskGroupEvent.new(group))
end

function TaskList:editGroupForCurrentFarm(group)
    g_client:getServerConnection():sendEvent(EditTaskGroupEvent.new(group))
end

function TaskList:copyGroupForCurrentFarm(newName, groupToCopyId)
    -- Sanity check the group exists
    local sourceGroup = self.taskGroups[groupToCopyId]
    if sourceGroup == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    local group = TaskGroup.new()
    group:copyValuesFromGroup(sourceGroup, false)
    group.name = newName

    g_client:getServerConnection():sendEvent(NewTaskGroupEvent.new(group))
end

function TaskList:getGroupListForCurrentFarm()
    local currentFarmId = self:getCurrentFarmId()
    local result = {}
    for _, group in pairs(self.taskGroups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            table.insert(result, {
                id = group.id,
                name = group.name,
                type = group.type,
                templateGroupId = group.templateGroupId
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
        local taskCopy = Task.new()
        taskCopy:copyValuesFromTask(task, true)
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

function TaskList:sendInitialClientState(connection, user, farm)
    connection:sendEvent(InitialClientStateEvent.new())
end

function TaskList.ShowActiveTaskNotifications()
    if g_currentMission.taskList.lastNotificationTime ~= nil and g_time - g_currentMission.taskList.lastNotificationTime < 12000 then
        return
    end

    local hasTasks = false
    local tempActive = {}
    for _, activeTask in pairs(g_currentMission.taskList.activeTasks) do
        table.insert(tempActive, activeTask)
        hasTasks = true
    end
    if not hasTasks then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO,
            g_i18n:getText("ui_no_active_tasks"))
    else
        table.sort(tempActive, TaskListUtils.taskSortingFunction)
        for _, activeTask in pairs(tempActive) do
            local description = string.format("%s - %s", activeTask.groupName, activeTask.detail)
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, description)
        end
    end

    g_currentMission.taskList.lastNotificationTime = g_time
end

local function addPlayerActionEvents(self, superFunc, ...)
    superFunc(self, ...)
    local _, id = g_inputBinding:registerActionEvent(InputAction.TL_SHOW_TASKS, self,
        TaskList.ShowActiveTaskNotifications, false, true, false,
        true)
    g_inputBinding:setActionEventTextVisibility(id, false)
end

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
    TaskList.sendInitialClientState)

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents, addPlayerActionEvents)

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, TaskList.hourChanged)
g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, TaskList.playerFarmChanged)

addModEventListener(TaskList)
