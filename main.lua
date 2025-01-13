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
    -- self.currentMonth = math.floor(g_currentMission.environment.currentPeriod)
    self.currentMonth = 5 -- TODO = replace

    -- TODO - remove below synthetic data
    local group1 = TaskGroup.new()
    group1.farmId = 1
    group1.name = "field 1"
    self.taskGroups[group1.id] = group1

    local task1 = Task.new()
    task1.detail = "Harvest"
    task1.priority = 1
    task1.month = 6
    task1.shouldRepeat = true
    task1.shouldRepeatMode = Task.shouldRepeat_MODE.MONTH
    self.taskGroups[group1.id].tasks[task1.id] = task1

    local task2 = Task.new()
    task2.detail = "Mulch"
    task2.priority = 1
    task2.month = 6
    task2.shouldRepeat = true
    task2.shouldRepeatMode = Task.shouldRepeat_MODE.MONTH
    self.taskGroups[group1.id].tasks[task2.id] = task2

    local group2 = TaskGroup.new()
    group2.farmId = 1
    group2.name = "field 2"
    self.taskGroups[group2.id] = group2

    local task3 = Task.new()
    task3.detail = "Harvest"
    task3.priority = 1
    task3.month = 6
    task3.shouldRepeat = true
    task3.shouldRepeatMode = Task.shouldRepeat_MODE.MONTH
    self.taskGroups[group2.id].tasks[task3.id] = task3

    local task4 = Task.new()
    task4.detail = "Cultivate"
    task4.priority = 1
    task4.month = 6
    task4.shouldRepeat = true
    task4.shouldRepeatMode = Task.shouldRepeat_MODE.MONTH
    self.taskGroups[group2.id].tasks[task4.id] = task4

    guiTodoList:initialize()
end

function TodoList:makeIsTodoListCheckEnabledPredicate()
    return function() return true end
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
    local month = math.floor(g_currentMission.environment.currentPeriod)
    if month ~= g_currentMission.todoList.currentMonth then
        g_currentMission.todoList:onMonthChanged()
    end
end

function TodoList:onMonthChanged()
    print("Month changed, updating tasks")
    -- for _, task in pairs(self.activeTasks) do
    --     task.overdue = true
    -- end

    for _, group in pairs(self.taskGroups) do
        self:addGroupTasksForCurrentMonth(group)
    end
    g_currentMission.todoList.currentMonth = math.floor(g_currentMission.environment.currentPeriod)
end

function TodoList:addGroupTasksForCurrentMonth(group)
    local currentMonth = math.floor(g_currentMission.environment.currentPeriod)
    local additions = false
    for _, task in pairs(group.tasks) do
        if task.month == currentMonth then
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

function TodoList:getTasksForMonthForCurrentFarm(month)
    local result = {}
    for _, group in pairs(self.taskGroups) do
        if group.farmId == currentFarmId or not g_currentMission.missionDynamicInfo.isMultiplayer then
            for _, task in pairs(group.tasks) do
                if task.month == month then
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

function TodoList:deleteGroup(groupId)
    local group = self.taskGroups[groupId]
    if group == nil then
        InfoDialog.show(g_i18n:getText("ui_group_not_found_error"))
        return
    end

    g_client:getServerConnection():sendEvent(DeleteGroupEvent.new(groupId))
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

function TodoList:addGroupForCurrentFarm(name)
    local currentFarmId = self:getCurrentFarmId()
    local group = TaskGroup.new()
    group.name = name
    -- local nextId = g_currentMission.todoList:generateId()
    -- self.taskGroups[nextId] = {
    --     id = nextId,
    --     farmId = currentFarmId,
    --     name = name,
    --     tasks = {}
    -- }

    g_client:getServerConnection():sendEvent(NewTaskGroupEvent.new(group))
end

function TodoList:copyGroupForCurrentFarm(newName, groupToCopyId)
    -- local currentFarmId = self:getCurrentFarmId()

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

    -- -- Create a new group table
    -- local nextId = g_currentMission.todoList:generateId()
    -- local newGroup = {
    --     id = nextId,
    --     farmId = currentFarmId,
    --     name = newName,
    --     tasks = {}
    -- }

    -- -- Copy tasks with new ids and add to the group
    -- for _, task in pairs(sourceGroup.tasks) do
    --     local nextTaskId = g_currentMission.todoList:generateId()
    --     local taskCopy = deepcopy(task)
    --     taskCopy.id = nextTaskId
    --     newGroup.tasks[nextTaskId] = taskCopy
    -- end

    -- TODO SEND EVENT HERE - DO NOT MUTATE
    -- self.taskGroups[nextId] = newGroup

    -- -- Add any tasks for the current month to activeTasks
    -- self:addGroupTasksForCurrentMonth(newGroup)
    -- g_messageCenter:publish(MessageType.TASK_GROUPS_UPDATED)
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
    local template = 'xxxxxxxx-xxxx-xxxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

-- function deepcopy(orig)
--     local orig_type = type(orig)
--     local copy
--     if orig_type == 'table' then
--         copy = {}
--         for orig_key, orig_value in next, orig, nil do
--             copy[deepcopy(orig_key)] = deepcopy(orig_value)
--         end
--         setmetatable(copy, deepcopy(getmetatable(orig)))
--     else -- number, string, boolean, etc
--         copy = orig
--     end
--     return copy
-- end

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, TodoList.hourChanged)
addModEventListener(TodoList)

function TodoList:sendInitialClientState(connection, user, farm)
    connection:sendEvent(InitialClientStateEvent.new())
end

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
    TodoList.sendInitialClientState)
